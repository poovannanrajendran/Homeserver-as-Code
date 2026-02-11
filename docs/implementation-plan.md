# Implementation Plan

## Delivery Approach
Implement in controlled phases with validation gates. Do not advance a phase until its acceptance checks pass.

## Phase 1: Host Baseline and Hardening
### Tasks
- Validate host networking, DNS, gateway, bridge configuration
- Verify NTP and timezone (`Europe/London`)
- Validate storage pools and free capacity
- Confirm cloud-init template integrity

### Acceptance checks
- Host reachable on intended management IP
- NTP synchronised and timezone correct
- VM template boots and cloud-init applies expected defaults

## Phase 2: Core VM Provisioning
### Tasks
- Clone and configure service VMs (docker/ai/automation/media/pbs)
- Assign static IPs and hostnames
- Install guest agents and baseline packages
- Apply initial firewall defaults and required allow rules

### Acceptance checks
- All target VMs boot cleanly and are reachable
- Guest-agent available where expected
- Baseline hardening completed without lockout

## Phase 3: Docker and Compose Foundations
### Tasks
- Install Docker Engine + Compose plugin on docker host and automation runner
- Create standard folder structure (`/srv/stacks`, `/srv/data`)
- Deploy foundational Compose projects in sequence

### Acceptance checks
- `docker compose ls` shows healthy projects
- Container restart policies are set (`unless-stopped`)
- Persistent bind mounts exist and are writable

## Phase 4: Service Deployment
### Tasks
- Deploy databases stack first
- Deploy platform services (n8n/Jenkins/Nginx)
- Deploy observability (Prometheus/Grafana/exporters)
- Deploy Nextcloud and media services
- Validate AI node services (Ollama + Open WebUI)

### Acceptance checks
- Services reachable on expected internal endpoints
- n8n configured for PostgreSQL backend
- Grafana and Prometheus operational for baseline dashboards

## Phase 5: Backup and Recovery
### Tasks
- Configure PBS datastore on external storage
- Define and schedule VM backup jobs
- Add service-level preflight and backup scripts
- Perform restore drill on non-production target

### Acceptance checks
- Nightly backup job completes successfully
- Restore test documented with timing and outcome
- Critical service data paths are covered

## Phase 6: Remote Access Hardening
### Tasks
- Enrol service VMs into Tailscale
- Validate remote access over Tailscale IP/MagicDNS
- Keep LAN access initially; tighten in stages
- Migrate admin surfaces to Tailscale-first

### Acceptance checks
- All designated nodes reachable via Tailscale
- No router port forwarding required
- Hardening changes documented and reversible

## Phase 7: Continuous Operations
### Tasks
- Standardise update workflow using compose update script
- Add CI checks for shell and compose validation
- Maintain change log and runbook updates

### Acceptance checks
- Updates are repeatable with no data loss
- CI passes on main and pull requests
- Documentation remains current with as-built state
