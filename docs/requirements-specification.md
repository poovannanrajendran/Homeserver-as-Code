# Requirements and Specification

## 1. Project Objective
Design and operate a stable, production-minded, single-node Proxmox home server platform that supports development, automation, AI workloads, media services, and reliable backup/recovery.

## 2. Non-Functional Requirements
- Single-node only (no cluster/HA assumptions)
- Reproducible deployment (cloud-init + scripts + Compose)
- Secure-by-default posture with staged hardening
- Persistent storage for all stateful services
- Backup-first operations before major updates
- Private remote access via Tailscale (no port-forwarding)

## 3. Hardware and Base Platform (Reference)
- Mini PC class host (Ryzen 7, 64 GB RAM, NVMe primary storage)
- Proxmox VE 9.x single-node
- VM disks on local NVMe-backed storage
- External disk for backup/media/large data domains

## 4. Workload Requirements

### 4.1 Mandatory VM Roles
- Docker host VM
- AI node VM
- Automation runner VM
- Media VM
- PBS VM
- Optional desktop/dev VMs

### 4.2 Containerised Services
- Databases: MariaDB, PostgreSQL, MongoDB, SQL Server Developer
- Platform: n8n, Jenkins, Nginx
- Observability: Prometheus, Grafana, node-exporter, cAdvisor
- Collaboration/content: Nextcloud
- Management: Portainer

### 4.3 AI Stack
- Ollama native on AI node
- Open WebUI service on AI node

### 4.4 Automation Runner
- Dedicated VM for scheduled Python workloads
- Repo-based deployment model (GitHub)
- Dedicated datastore pair for workload isolation (Postgres + MongoDB)

## 5. Network and Access Specification
- LAN subnet in production is private RFC1918 space (redacted in public docs)
- Public docs must use documentation ranges (`192.0.2.0/24`)
- Tailscale installed on critical service VMs
- Access model:
  - Home/LAN access retained during initial phases
  - Outside access through Tailscale addresses
  - Admin surfaces tightened to Tailscale-only after validation

## 6. Data and Persistence Specification
- Compose stacks use bind mounts for critical service state
- Data path conventions:
  - Compose manifests: `/srv/stacks`
  - Service data: `/srv/data`
  - Large external datasets: mounted external storage paths
- Backups target PBS datastore
- Service-level data capture should be scriptable and testable

## 7. Security Specification
- Secrets must never be committed to Git
- `.env.example` contains placeholders only
- Password rotation required after bootstrap and accidental exposure
- Firewall policy staged:
  - allow required service ports initially
  - reduce LAN exposure by interface/subnet over time

## 8. Operability Specification
- Every stack must be updatable with `docker compose pull` + `up -d`
- Pre-update checks and post-update verification are required
- Backup health and restore testing must be documented
- Timezone and NTP consistency across host and VMs

## 9. Acceptance Criteria
- All required VMs are provisioned and reachable
- Core containers run with persistent storage and expected ports
- n8n uses PostgreSQL backend (not embedded SQLite)
- PBS backups run on schedule and at least one restore test succeeds
- Tailscale connectivity works for all designated service VMs
- Documentation is sufficient for a clean rebuild by a third party
