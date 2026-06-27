#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" = "0" ]; then
  mkdir -p /home/paperclip/.paperclip
  chown -R paperclip:paperclip /home/paperclip/.paperclip
  exec gosu paperclip "$0"
fi

INSTANCE_ID="${PAPERCLIP_INSTANCE_ID:-paperclip-locallab}"
INSTANCE_DIR="${HOME}/.paperclip/instances/${INSTANCE_ID}"
ENV_PATH="${INSTANCE_DIR}/.env"

mkdir -p \
  "${INSTANCE_DIR}/data/storage" \
  "${INSTANCE_DIR}/data/backups" \
  "${INSTANCE_DIR}/logs" \
  "${INSTANCE_DIR}/secrets"

if [ -z "${PAPERCLIP_AGENT_JWT_SECRET:-}" ]; then
  if [ -f "${ENV_PATH}" ] && grep -q '^PAPERCLIP_AGENT_JWT_SECRET=' "${ENV_PATH}"; then
    # shellcheck disable=SC1090
    source "${ENV_PATH}"
  else
    PAPERCLIP_AGENT_JWT_SECRET="$(node -e 'console.log(require("crypto").randomBytes(48).toString("hex"))')"
  fi
fi
export PAPERCLIP_AGENT_JWT_SECRET

cat > "${ENV_PATH}" <<EOF
PAPERCLIP_AGENT_JWT_SECRET=${PAPERCLIP_AGENT_JWT_SECRET}
DATABASE_URL=${DATABASE_URL}
PAPERCLIP_PUBLIC_URL=${PAPERCLIP_PUBLIC_URL:-http://localhost:3102}
OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-http://host.docker.internal:11434}
OLLAMA_OPENAI_BASE_URL=${OLLAMA_OPENAI_BASE_URL:-http://host.docker.internal:11434/v1}
EOF

node <<'NODE'
const fs = require("fs");
const path = require("path");

const instanceDir = process.env.INSTANCE_DIR || `${process.env.HOME}/.paperclip/instances/${process.env.PAPERCLIP_INSTANCE_ID || "paperclip-locallab"}`;
const configPath = path.join(instanceDir, "config.json");
const mcpPath = path.join(instanceDir, "mcp.json");
const port = Number(process.env.PAPERCLIP_PORT || 3102);
const publicUrl = (process.env.PAPERCLIP_PUBLIC_URL || `http://localhost:${port}`).replace(/\/+$/, "");

const config = {
  $meta: {
    version: 1,
    updatedAt: new Date().toISOString(),
    source: "configure"
  },
  database: {
    mode: "postgres",
    connectionString: process.env.DATABASE_URL,
    backup: {
      enabled: true,
      intervalMinutes: 60,
      retentionDays: 30,
      dir: `${instanceDir}/data/backups`
    }
  },
  logging: {
    mode: "file",
    logDir: `${instanceDir}/logs`
  },
  server: {
    deploymentMode: "authenticated",
    exposure: "private",
    bind: "lan",
    host: "0.0.0.0",
    port,
    allowedHostnames: [
      "localhost",
      "127.0.0.1",
      "host.docker.internal",
      "paperclip-locallab"
    ],
    serveUi: true
  },
  auth: {
    baseUrlMode: "explicit",
    publicBaseUrl: publicUrl,
    disableSignUp: false
  },
  telemetry: {
    enabled: false
  },
  storage: {
    provider: "local_disk",
    localDisk: {
      baseDir: `${instanceDir}/data/storage`
    }
  },
  secrets: {
    provider: "local_encrypted",
    strictMode: false,
    localEncrypted: {
      keyFilePath: `${instanceDir}/secrets/master.key`
    }
  }
};

fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);

const mcpServers = {};

if (process.env.N8N_MCP_URL && process.env.N8N_MCP_BEARER_TOKEN) {
  mcpServers["n8n-remote"] = {
    command: "supergateway",
    args: [
      "--streamableHttp",
      process.env.N8N_MCP_URL,
      "--header",
      `authorization: Bearer ${process.env.N8N_MCP_BEARER_TOKEN}`
    ]
  };
}

if (process.env.LOCAL_MAC_MCP_URL) {
  mcpServers["local-mac-mcp"] = {
    command: "supergateway",
    args: [
      "--streamableHttp",
      process.env.LOCAL_MAC_MCP_URL
    ]
  };
}

fs.writeFileSync(mcpPath, `${JSON.stringify({ mcpServers }, null, 2)}\n`);
NODE

exec paperclipai run --no-repair --instance "${INSTANCE_ID}"
