# Architecture (Single Node)

## Platform
- Hypervisor: Proxmox VE (single node)
- VM strategy: cloud-init template + scripted provisioning
- Container strategy: Docker Compose per service domain

## Logical Workloads
- `docker-host-01`: shared Compose services
- `automation-runner-01`: scheduled Python workloads, Memex runner API, n8n, observability stack
- `ai-node-01`: OpenClaw gateway, Ollama, Open WebUI, Mem0 memory integration, Discord channel runtime
- `docker-host-01`: includes Qdrant in the databases stack for OpenClaw/Memex memory
- `media-01`: Jellyfin/Plex (Proxmox LXC container; Jellyfin runs native, not Docker)
- `pbs-01`: Proxmox Backup Server

## Network (Redacted Example)
Use documentation ranges in public docs:
- LAN example: `192.0.2.0/24`
- Gateway example: `192.0.2.1`
- Hypervisor example: `192.0.2.250`

## Remote Access Model
- Private-by-default via Tailscale
- No router port forwarding required
- Tighten LAN admin exposure after validation

## OpenClaw Channels
- Telegram remains the primary ingress channel for broad smoke tests.
- Discord is now enabled on `ai-node-01` through the official `@openclaw/discord` plugin.
- Current live Discord test guild is allowlisted for `poovannan's server` and routes the `#openclaw_d` channel to `fury` via top-level `bindings[]`.
- Discord is configured from `~/.env` on `ai-node-01` using `DISCORD_BOT_TOKEN`; the token is not stored in the repository.
