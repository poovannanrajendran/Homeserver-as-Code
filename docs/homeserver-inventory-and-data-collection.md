# HomeServer Inventory and Data Collection Reference

## Purpose
This page is the working reference for the homeserver environment. It captures:
- servers and VMs
- Docker and compose workloads
- application URLs
- databases
- observability and health checks
- cron and scheduled jobs
- OpenClaw operational notes

## Core Hosts

### Proxmox Host
- Hostname: `pve`
- Host IP: `192.168.1.250`
- Access: Proxmox web UI
- Role: virtualization host for the homelab

### Docker Host VM
- VMID: `100`
- Name: `docker-host-01`
- LAN IP: `192.168.1.20`
- Tailscale IP: `100.81.51.70`
- Role: main Docker/Compose workload host
- Notable services: mail relay, Nextcloud, Jenkins, n8n, Grafana source services, databases, monitoring helpers, Qdrant

### AI Node VM
- VMID: `101`
- Name: `ai-node-01`
- LAN IP: `192.168.1.24`
- Tailscale hostname: `ai-node-01.tail4bbda6.ts.net`
- Role: OpenClaw / Jarvis AI assistant host
- Notes: OpenClaw runs here with local models and external provider fallbacks

### Automation Runner VM
- VM name: `automation-runner-01`
- LAN IP: `192.168.1.30`
- Role: observability, dashboarding, host health collection, automation runner, Memex runner API
- Grafana URL: `http://192.168.1.30:3000`
- Prometheus URL: `http://192.168.1.30:9090`
- Alertmanager URL: `http://192.168.1.30:9093`

## OpenClaw / Jarvis

### Access
- Web UI: `https://ai-node-01.tail4bbda6.ts.net`
- Gateway host: `ai-node-01`
- Chat/Control UI: OpenClaw dashboard and chat interface on the AI node
- Current runtime: `2026.6.8 (844f405)`
- Gateway loopback: `127.0.0.1:18789`
- Runtime home: `/var/lib/openclaw`
- Config file: `/var/lib/openclaw/.openclaw/openclaw.json`

### Connected channels
- Telegram: configured and running
- WhatsApp: disabled unless explicitly re-enabled

### Provider configuration
- Default agent: `fury`
- Default chat provider: `google/gemini-3-flash-preview` with fallback model chain
- Backup providers configured in the environment:
  - OpenRouter
  - DeepSeek
  - Google Gemini
  - OpenAI
  - xAI
  - Ollama for local models

### Memory and agents
- Agents registered: `fury`, `cyborg`, `wayne`, `oracle`, `banner`, `xavier`, `deadpool`, `strange`, `diana`, `loki`, `stark`
- Agent instruction files: `/var/lib/openclaw/.openclaw/agents/<agent>/agent/AGENTS.md`
- Memory plugins: `openclaw-mem0` and `memory-wiki`
- Mem0 mode: open-source
- Mem0 local models: Ollama `nomic-embed-text` for embeddings and `llama3.2:3b` for extraction
- Mem0 vector store: Qdrant on `192.168.1.20:6333`, collection `mem0_768d`
- Mem0 Qdrant secret: `/etc/openclaw/mem0.env`, loaded by `openclaw-gateway.service`
- Per-agent config overrides are not accepted by the live OpenClaw schema. Use Mem0 `--agent-id` namespaces where supported.
- Memex MCP server: `memex`, forced-command SSH to `automation-runner-01`

### Operational notes
- Heartbeat was tuned to use a smaller local model when practical
- OpenClaw gateway access requires pairing and a secure browser context for the control UI
- Google Workspace CLI is installed on `ai-node-01` for Gmail and related integrations
- Use `sudo -u openclaw -H sh -lc '<command>'` for OpenClaw filesystem operations; do not rely on `~` from the `labadmin` shell.

## Databases

### Local Postgres: lloyds market news digest
- URL: `<redacted; see local/private/homeserver-inventory-and-data-collection.md>`
- Usage: primary Postgres for the `lloyds-market-news-digest` project

### Local Postgres: memex
- URL: `<redacted; see local/private/homeserver-inventory-and-data-collection.md>`
- Usage: project database for memex work

### Remote Postgres: youtube summary fallback
- URL: `<redacted; see local/private/homeserver-inventory-and-data-collection.md>`
- Usage: fallback database used by summary scripts

### Supabase Postgres
- Host: `db.gzrxtjaujbcgwifupebq.supabase.co:5432`
- URL: stored in project environment on the runner
- Usage: Supabase backend checks and connected app services

### MongoDB Atlas
- URI: `<redacted; see local/private/homeserver-inventory-and-data-collection.md>`
- Usage: raw source data for `lloyds-market-news-digest`
- Health check: TCP probe against `poovannnan.6r4o1.mongodb.net:27017`

### n8n database
- Backend: PostgreSQL (`DB_TYPE=postgresdb`)
- Host path: managed by the `postgres` service in the platform stack
- Container path: `/home/node/.n8n`
- Notes: this describes the `docker-host-01` platform n8n; the Paperclip n8n instance on `automation-runner-01` remains a separate local SQLite-backed deployment

### RAG / AI support databases
- RAG Postgres: `<redacted; see local/private/homeserver-inventory-and-data-collection.md>`
- Qdrant: `http://192.168.1.20:6333`
- Qdrant health: `/healthz` and `/readyz`; `/health` returns 404 on Qdrant 1.17.1
- Qdrant API key: `QDRANT_API_KEY` in `/srv/stacks/databases/.env`
- Qdrant collections in use:
  - `mem0_768d` — OpenClaw Mem0 semantic memory
  - `memex-knowledge` — Memex payload-only cache, 7,478 points

## Docker and Compose Workloads on docker-host-01

### Running containers observed
- `smtp-relay`
- `nextcloud-cron`
- `portainer`
- `jenkins`
- `n8n`
- `grafana`
- `redis`
- `postgres`
- `mariadb`
- `sqlserver`
- `mongo`
- `nextcloud`
- `nginx`
- `cadvisor`
- `prometheus`
- `node-exporter`

### Important ports
- Portainer: `9443`
- Jenkins: `8081`
- n8n: `5678`
- Grafana: `3000`
- Prometheus: `9090`
- Node exporter: `9100`
- cAdvisor: `8080`
- SMTP relay: `1587`
- Nextcloud: `8082`
- Nginx: `80`

## Application URLs

### Internal services
- Authentik: `http://192.168.1.20:9000`
- Outline: `http://192.168.1.20:3010`
- Jenkins: `http://192.168.1.20:8081`
- Nextcloud: `http://192.168.1.20:8082`
- Portainer: `https://192.168.1.20:9443`
- n8n: `http://192.168.1.20:5678`
- Grafana: `http://192.168.1.30:3000`
- Prometheus: `http://192.168.1.30:9090`
- Alertmanager: `http://192.168.1.30:9093`

### Vercel apps
- `https://submission-triage-copilot.vercel.app`
- `https://portfolio-mix-dashboard.vercel.app`
- `https://risk-appetite-parser.vercel.app`
- `https://slip-reviewer.vercel.app`
- `https://class-of-business-classifier.vercel.app`
- `https://exposure-accumulation-heatmap.vercel.app`
- `https://cat-event-briefing.vercel.app`
- `https://policy-endorsement-diff-checker.vercel.app`
- `https://referral-priority-queue-scorer.vercel.app`
- `https://claims-fnol-triage-assistant.vercel.app`
- `https://binder-capacity-monitor.vercel.app`
- `https://treaty-structure-explainer.vercel.app`
- `https://exposure-clash-detector.vercel.app`
- `https://claims-leakage-flagger.vercel.app`
- `https://broker-submission-builder.vercel.app`
- `https://exposure-scenario-modeller.vercel.app`
- `https://mrc-checker.vercel.app`
- `https://placement-tracker.vercel.app`
- `https://wording-risk-diff-checker.vercel.app`
- `https://regulatory-update-digest.vercel.app`
- `https://meeting-prep-briefing.vercel.app`
- `https://renewal-intelligence-copilot.vercel.app`
- `https://ops-health-monitor.vercel.app`
- `https://data-quality-validator.vercel.app`
- `https://sanctions-screening-aid.vercel.app`
- `https://qbr-narrative-generator.vercel.app`
- `https://team-capacity-planner.vercel.app`
- `https://stakeholder-comms-drafter.vercel.app`
- `https://insurance-ai-readiness-scorer.vercel.app`
- `https://loss-ratio-triangulator.vercel.app`
- `https://challenge-portfolio-showcase.vercel.app`
- `https://poovi-me-site.vercel.app`
- `https://memex-poovi.vercel.app`

## Observability Stack

### Stack location
- Host path: `/srv/stacks/observability`

### Main services
- Grafana
- Prometheus
- Alertmanager
- Loki
- Promtail
- Node exporter
- cAdvisor
- Blackbox exporter
- Uptime Kuma
- Postgres exporter for local checks

### Dashboard
- Name: `HomeServer Health`
- UID: `homeserver-health`
- Dashboard URL: `http://192.168.1.30:3000/d/homeserver-health/homeserver-health`
- Name: `Vercel + Lloyds Pages`
- UID: `vercel-lloyds-pages`
- Dashboard URL: `http://192.168.1.30:3000/d/vercel-lloyds-pages/vercel-2b-lloyds-pages`

### What the dashboard shows
- Proxmox health
- VM ping health
- VM SSH health
- HTTP probe success
- TCP probe success
- Supabase DB check
- Postgres checks for `lloyds_digest`, `memex`, and `youtube_liked_videos`
- Mongo Atlas TCP check
- Disk usage trends for `/` and `/var`
- Postgres DB size growth
- Probe duration by endpoint
- Cron job counts by host
- HTTP and TCP failure counters
- Vercel app health plus `https://poovannanrajendran.github.io/lloyds-market-news-digest/`

### Health collector output
- Script: `/srv/stacks/observability/scripts/host_checks.sh`
- Env: `/srv/stacks/observability/scripts/host_checks.env`
- Output metrics file: `/srv/stacks/observability/textfile/host_checks.prom`
- Schedule: every 5 minutes

### Alerting
- Prometheus rules: `/srv/stacks/observability/prometheus/rules/homeserver-alerts.yml`
- Alertmanager config: `/srv/stacks/observability/alertmanager/alertmanager.yml`
- Receivers: email + Telegram

## Scheduled Jobs and Automation

### Host health collector cron
- Runs every 5 minutes
- Collects Proxmox, VM, DB, disk, and cron inventory data

### OpenClaw updates
- OpenClaw update schedule was tuned for early morning execution
- Manual update runs can be triggered when needed
- Safe reboot windows should only run when `/var/run/reboot-required` exists

### System update posture
- OS updates are handled separately from OpenClaw updates
- Reboots are only required when the kernel or pending reboot marker indicates it

## Useful Run Commands

### Observability
```bash
cd /srv/stacks/observability
docker compose up -d
docker compose restart grafana prometheus alertmanager
```

### Reload Prometheus
```bash
curl -fsS -X POST http://127.0.0.1:9090/-/reload
```

### Health checks
```bash
curl -fsS http://127.0.0.1:3000/api/health
curl -fsS http://127.0.0.1:9090/-/healthy
curl -fsS http://127.0.0.1:9093/-/healthy
```

## Notes
- This document is the shared map of the current environment.
- It should be updated whenever a server, URL, database, provider, or scheduled job changes.
- Sensitive credentials should be stored only in the host secret files and not duplicated here.
