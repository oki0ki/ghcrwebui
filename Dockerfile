# syntax=docker/dockerfile:1
# Buduje z oficjalnego open-webui i nadpisuje ZMODYFIKOWANE pliki z tego repo

FROM node:22-alpine3.20 AS build
WORKDIR /app
RUN apk add --no-cache git

# 1. Sklonuj bazowy open-webui
RUN git clone --depth=1 https://github.com/open-webui/open-webui.git .

# 2. NADPISZ zmodyfikowanymi plikami z TWOJEGO repo
COPY src/routes/+layout.svelte src/routes/+layout.svelte
COPY src/routes/(app)/+layout.svelte "src/routes/(app)/+layout.svelte"
COPY src/lib/components/chat/MessageInput.svelte src/lib/components/chat/MessageInput.svelte

# 3. Zbuduj frontend z TWOIMI zmianami
RUN npm ci --force
ENV APP_BUILD_HASH=ghcrwebui-custom
RUN npm run build

# --- Backend image ---
FROM python:3.11-slim-bookworm

ENV PORT=7860 \
    HOST=0.0.0.0 \
    OPENAI_API_BASE_URL=https://generative-api-g7qi.encr.app/v1 \
    OPENAI_API_KEY=connect \
    DEFAULT_LOCALE=pl \
    WEBUI_SECRET_KEY=ghcrwebui-secret-2025 \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false \
    DOCKER=true \
    ENV=prod \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl build-essential python3-dev ffmpeg pandoc gcc netcat-openbsd jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app/backend

COPY --from=build /app/backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir uv && \
    pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    uv pip install --system -r requirements.txt --no-cache-dir

COPY --from=build /app/build /app/build
COPY --from=build /app/CHANGELOG.md /app/CHANGELOG.md
COPY --from=build /app/package.json /app/package.json
COPY --from=build /app/backend .

EXPOSE 7860

HEALTHCHECK CMD curl --silent --fail http://localhost:7860/health | jq -ne "input.status == true" || exit 1

CMD ["bash", "start.sh"]
