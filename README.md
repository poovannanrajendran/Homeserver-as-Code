# Homeserver-as-Code

Production-minded, single-node home-lab blueprint for Proxmox VE with reproducible VM and container operations.

> Public-safe repository: no real credentials, hostnames, or private LAN ranges are stored here.

## Purpose
This project exists to turn a personal home server build into a repeatable, maintainable, and recoverable infrastructure blueprint.

It was created to:
- standardise VM and container deployment with scriptable workflows
- avoid one-off manual configuration drift
- support reliable backup/recovery operations
- document operational decisions and runbooks in one place
- make future rebuilds, migrations, and audits significantly easier

## Why This Was Published Publicly
This repository is published as a reusable reference implementation for other operators running single-node home labs.

Publishing benefits:
- transparent architecture and operations patterns
- community reuse and peer review
- durable documentation independent of any one machine
- clean separation between public infrastructure code and private secrets

## Attribution
This repository was fully generated and implemented with **Codex 5.3** in less than 2 hours.

## Software Stack
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white) ![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white) ![Portainer](https://img.shields.io/badge/Portainer-13BEF9?style=for-the-badge&logo=portainer&logoColor=white) ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)

![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white) ![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=for-the-badge&logo=mongodb&logoColor=white) ![Grafana](https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white) ![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white) ![Jenkins](https://img.shields.io/badge/Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white)

![Nextcloud](https://img.shields.io/badge/Nextcloud-0082C9?style=for-the-badge&logo=nextcloud&logoColor=white) ![n8n](https://img.shields.io/badge/n8n-EA4B71?style=for-the-badge&logo=n8n&logoColor=white) ![Tailscale](https://img.shields.io/badge/Tailscale-242424?style=for-the-badge&logo=tailscale&logoColor=white) ![Jellyfin](https://img.shields.io/badge/Jellyfin-00A4DC?style=for-the-badge&logo=jellyfin&logoColor=white) ![Ollama](https://img.shields.io/badge/Ollama-111111?style=for-the-badge&logoColor=white)

## Scope
- Single-node Proxmox architecture
- Cloud-init driven VM provisioning patterns
- Docker Compose-first service deployment
- Backup and update operational runbooks
- Tailscale-first remote access model (no public port forwarding)

## Public Safety Model
- Uses documentation network ranges (`192.0.2.0/24`) in examples
- Uses placeholder credentials only (`CHANGE_ME`)
- Real secrets belong in private `.env` files, a secrets manager, or vault

## Documentation Map
- Documentation index: `docs/index.md`
- Requirements + specification: `docs/requirements-specification.md`
- Implementation plan: `docs/implementation-plan.md`
- Architecture overview: `docs/architecture.md`
- Visual diagrams: `docs/diagrams.md`
- Operations runbooks: `docs/runbooks.md`

## Repository Layout
- `docs/` architecture, requirements, implementation phases, diagrams, runbooks
- `stacks/` compose stacks (databases/platform/observability/nextcloud/media)
- `scripts/` reusable operational scripts
- `infra/` cloud-init and VM inventory examples
- `examples/` redacted `.env` templates

## Quick Start
1. Copy env templates:
   ```bash
   cp examples/env/databases.env.example stacks/databases/.env
   cp examples/env/platform.env.example stacks/platform/.env
   cp examples/env/nextcloud.env.example stacks/nextcloud/.env
   ```
2. Set strong secrets in local `.env` files.
3. Deploy stack-by-stack:
   ```bash
   cd stacks/databases && docker compose up -d
   cd ../platform && docker compose up -d
   cd ../observability && docker compose up -d
   cd ../nextcloud && docker compose up -d
   ```
4. Use `scripts/update_compose_stack.sh` for controlled upgrades.

## Security Baseline
- Keep this repository public-safe only
- Rotate any secret if it was ever exposed
- Restrict admin surfaces to Tailscale where possible
- Keep DB ports private to trusted interfaces/hosts

## Licence
MIT
