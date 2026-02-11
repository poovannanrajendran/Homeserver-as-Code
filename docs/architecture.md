# Architecture (Single Node)

## Platform
- Hypervisor: Proxmox VE (single node)
- VM strategy: cloud-init template + scripted provisioning
- Container strategy: Docker Compose per service domain

## Logical Workloads
- `docker-host-01`: shared Compose services
- `automation-runner-01`: scheduled Python workloads and dedicated data stores
- `ai-node-01`: Ollama + Open WebUI
- `media-01`: Jellyfin/Plex
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
