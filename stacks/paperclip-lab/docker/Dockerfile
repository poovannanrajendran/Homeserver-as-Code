FROM node:22-bookworm-slim

ARG PAPERCLIP_VERSION=latest

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gosu \
    git \
    jq \
    psmisc \
    procps \
    python3 \
    python3-venv \
    rsync \
    tar \
    unzip \
    zip \
  && rm -rf /var/lib/apt/lists/*

RUN printf '#!/usr/bin/env sh\nprintf "Open this URL on the Docker host: %s\\n" "$1" >&2\nexit 0\n' > /usr/local/bin/xdg-open \
  && chmod +x /usr/local/bin/xdg-open

RUN npm install -g \
  "paperclipai@${PAPERCLIP_VERSION}" \
  supergateway \
  @anthropic-ai/claude-code \
  @google/gemini-cli \
  @openai/codex

RUN useradd --create-home --uid 10001 --shell /bin/bash paperclip

COPY docker/entrypoint.sh /usr/local/bin/paperclip-lab-entrypoint
RUN chmod +x /usr/local/bin/paperclip-lab-entrypoint

WORKDIR /home/paperclip
ENV HOME=/home/paperclip

EXPOSE 3102

ENTRYPOINT ["paperclip-lab-entrypoint"]
