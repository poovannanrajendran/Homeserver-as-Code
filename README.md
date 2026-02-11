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
