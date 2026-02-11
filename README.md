# Homeserver-as-Code

Production-minded, single-node home-lab blueprint for Proxmox VE with reproducible VM and container operations.

> Public-safe repository: no real credentials, hostnames, or private LAN ranges are stored here.

## Attribution
This repository was generated and implemented with **Codex 5.3** in a focused sprint workflow.

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

## Repository Layout
- `docs/` architecture, implementation phases, runbooks
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
