# CLAUDE.md — Proxmox Homeserver Project

This repo manages a single-node Proxmox homelab: infrastructure-as-code, Docker Compose stacks, runbooks, and day-2 ops scripts.

## Project Layout

```
stacks/          Docker Compose definitions (one dir per stack)
scripts/         Bootstrap, rollout, and maintenance scripts
examples/env/    .env.example files — copy to stacks/<stack>/.env and fill secrets
docs/            Architecture, runbooks, diagrams, per-stack guides
local/           Live context files (not committed to shared history)
  INVENTORY.md   Authoritative live inventory — update after any infra change
  ACCESS.md      Connection endpoints and mechanisms
  OPS_USER.md    codex_agent_agent account management
  REMEDIATION_CHECKLIST.md  Known issues and action items
  SECRETS.md     Secret locations (do NOT commit actual secrets here)
```

## Infrastructure at a Glance

| Host | IP | Role |
|------|----|------|
| `pve` (Proxmox) | 192.168.1.250 | Hypervisor |
| `docker-host-01` (VM 100) | 192.168.1.20 | Most Docker stacks |
| `ai-node-01` (VM 101) | 192.168.1.24 | AI workloads — OpenClaw gateway |
| `automation-runner-01` (VM 103) | 192.168.1.30 | n8n, Jenkins, Memex runner API, observability stack |
| `pbs-01` (VM 105) | 192.168.1.25 | Proxmox Backup Server |
| `jellyfin-01` (LXC 106) | 192.168.1.26 | Jellyfin media server |

Remote access: Tailscale-first. Docker host Tailscale DNS: `docker-host-01.tail4bbda6.ts.net`

## Active Docker Stacks (`/srv/stacks` on docker-host-01)

- `authentik` — IdP (OIDC), healthy on :9000/:9444
- `outline` — Family wiki, healthy on :3010
- `nextcloud` — File sync, running on :8082
- `portainer` — Docker UI on :9443
- `platform` — Nginx reverse proxy on :80
- `databases` — Postgres, MySQL, MongoDB, Qdrant (sqlserver deferred/disabled via profile)
- `smtp-relay` — Postfix relay on :1587 → Purelymail

Qdrant is part of the `databases` stack:
- Container: `qdrant`
- LAN endpoint: `http://192.168.1.20:6333`
- Health endpoints: `/healthz` and `/readyz` (`/health` returns 404 on Qdrant 1.17.1)
- API key: stored in `/srv/stacks/databases/.env` as `QDRANT_API_KEY`; do not print or commit it.

## Active Docker Stacks (`/srv/stacks` on automation-runner-01)

- `observability` — full stack: Grafana :3000, Prometheus :9090, Alertmanager :9093, Loki :3100, Promtail, Node Exporter :9100, cAdvisor :8080, Blackbox :9115, Uptime Kuma :3002
- n8n — workflow automation
- Memex runner — `memex-runner.service` serving `scripts/runner_api.py` on :8000 from `/home/labadmin/memex`
- Prometheus scrapes Qdrant remotely using `/srv/stacks/observability/prometheus/secrets/qdrant_api_key`
- Host checks include `obs_qdrant_http_up` using `/srv/stacks/observability/scripts/host_checks.env`

## OpenClaw / Memex Integration

- OpenClaw host: `ai-node-01` (`192.168.1.24`)
- OpenClaw config: `/var/lib/openclaw/.openclaw/openclaw.json` (not `config.json5`)
- OpenClaw home: `/var/lib/openclaw`
- Secure UI: `https://ai-node-01.tail4bbda6.ts.net`
- Gateway loopback: `127.0.0.1:18789`
- Telegram is configured; WhatsApp is disabled unless explicitly re-enabled.
- Agents registered: `fury`, `cyborg`, `wayne`, `oracle`, `banner`, `xavier`, `deadpool`, `strange`, `diana`, `loki`, `stark`; `fury` is default.
- Memory stack: `openclaw-mem0` in OSS mode + `memory-wiki` bridge.
- Gateway auth is now network-only for the control UI: `gateway.auth.mode = none` and `gateway.controlUi.dangerouslyDisableDeviceAuth = true`; nginx no longer adds a browser basic-auth challenge.
- Telegram is explicitly routed to `fury`; `workspace-fury/BOOTSTRAP.md` has been removed so Telegram follows the seeded identity and memory path.
- Mem0 uses local Ollama (`nomic-embed-text`, `llama3.2:3b`) and Qdrant collection `mem0_768d`.
- Mem0 Qdrant secret is loaded from `/etc/openclaw/mem0.env` via a systemd drop-in.
- Agent memory namespaces are logical, not separate Qdrant collections: the live store is shared `mem0_768d` with `user_id` values like `poovi:agent:oracle`.
- Memex MCP is registered as `memex` over forced-command SSH to `automation-runner-01`.
- Memex Qdrant payload cache is `memex-knowledge` with 7,478 points; semantic Memex recall is via MCP, not Mem0.
- Live OpenClaw schema rejects `agents.list[*].plugins`; per-agent Mem0 config overrides are not supported. Use runtime `--agent-id` namespaces where the Mem0 CLI supports them.

## Ops User

All automation and remote commands use `codex_agent_agent`. See `local/OPS_USER.md` for rollout/disable procedures.

## Key Conventions

- **Secrets**: never commit `.env` files. Use `examples/env/*.env.example` as templates.
- **Inventory**: update `local/INVENTORY.md` after any VM/CT/stack change.
- **Stacks**: deploy with `cd /srv/stacks/<stack> && docker compose up -d`.
- **Backups**: PBS job covers VMs 100–104. LXC 106 (Jellyfin) is NOT in the scheduled job — add it (see REMEDIATION_CHECKLIST.md).
- **Database ports 5432/3306/27017** are currently exposed on 0.0.0.0. Firewall/bind hardening is deferred (tracked in REMEDIATION_CHECKLIST.md).

## Open Issues (as of 2026-05-01)

See `local/REMEDIATION_CHECKLIST.md` for full details:
1. No current OpenClaw-specific blockers remain in the observability path; Grafana Qdrant dashboard `qdrant_prom_only_divakar` is now imported and live on the runner.

## Storage

- Proxmox host external disk: `/mnt/usb-4tb` (~3.6T, ext4)
- Media path (host): `/mnt/usb-4tb/media` → bind-mounted into Jellyfin LXC at `/mnt/media-library`
- Media folders: `movies`, `tv`, `music`, `home-videos`, `photos`, `concerts`, `audiobooks`

## SSH Access

```bash
ssh root@192.168.1.250          # Proxmox host
ssh labadmin@192.168.1.20       # docker-host-01
ssh labadmin@192.168.1.30       # automation-runner-01 (observability, n8n, Memex)
ssh labadmin@192.168.1.24       # ai-node-01 (OpenClaw)
pct exec 106 -- <cmd>           # Jellyfin LXC (from Proxmox host)
```
