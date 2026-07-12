# Update and Reboot Maintenance Checklist

## Purpose
This checklist is the control point for long-overdue maintenance across the homelab:
- Proxmox host
- VMs
- Docker host and compose workloads
- application services inside the VMs/containers
- post-reboot validation after patching

Use this before making changes, and again after any reboot.

## Systems to Check

### Proxmox Host
- Host: `pve`
- Check:
  - package updates
  - Proxmox kernel updates
  - ZFS / storage stack updates
  - SSH / OpenSSL / systemd updates
  - cluster and firewall components
  - backup service health

### Docker Host VM
- Host: `docker-host-01`
- Check:
  - Ubuntu package updates
  - Docker engine / containerd / compose plugin updates
  - compose project images
  - running containers:
    - Outline
    - Authentik
    - SMTP relay
    - Nextcloud / cron
    - Portainer
    - Jenkins
    - n8n
    - Children Email Digest (`ced-app`)
    - Grafana / Prometheus / node-exporter / cAdvisor
    - databases (Postgres, MariaDB, Mongo, Redis)

### Automation Runner VM
- Host: `automation-runner-01`
- Check:
  - Ubuntu package updates
  - scheduled jobs
  - YouTube sync timer (`youtube-sync.timer`)
  - observability stack
  - Grafana / Prometheus / Alertmanager health
  - local database connectivity used by dashboards and collectors

### AI Node VM
- Host: `ai-node-01`
- Check:
  - Ubuntu package updates
  - OpenClaw package/service state
  - OpenClaw weekly update timer
  - OpenClaw weekly OS update timer
  - conditional reboot timer
  - Telegram / WhatsApp channel health
  - browser control / gateway availability

### Other Managed Guests
- Check that each guest is reachable and healthy after any host reboot:
  - `docker-host-01`
  - `ai-node-01`
  - `automation-runner-01`
  - `pbs-01`
  - `jellyfin-01` LXC

## Update Inventory

### High Priority
- Proxmox host packages and kernel
- `docker.io`, `containerd`, `docker-compose-v2`
- `systemd`, `openssh`, `openssl`
- core networking and security packages

### Medium Priority
- application base images:
  - `grafana`
  - `prometheus`
  - `nextcloud`
  - `portainer`
  - `jenkins`
  - `n8n`
  - `outline`
  - `authentik`
  - `postgres`
  - `mariadb`
  - `mongo`
  - `redis`

### Low Priority
- documentation-only or non-runtime packages
- desktop/helper packages on VMs that do not affect service availability

## Pre-Reboot Checklist
Before rebooting any host:
- Confirm backups are current.
- Confirm you can reach the host by SSH or console.
- Check whether any jobs are actively running:
  - YouTube sync
  - OpenClaw update
  - dashboard/observability collector
  - any long compose maintenance
  - Children Email Digest pipeline/backfill
- Record the currently running timers and active containers.
- Notify yourself if a service window is in progress.

## Reboot Order
Recommended order for a broad maintenance window:
1. Proxmox host, only if the host kernel or Proxmox stack needs it.
2. Docker host VM.
3. Automation runner VM.
4. AI node VM.
5. Any remaining guest LXC/VMs if they are not already covered.

## Monthly Automation
The recurring maintenance job now runs from `automation-runner-01`.

Planned schedule:
- `*-*-01 03:00:00` via `monthly-maintenance.timer`

Behavior:
- starts on the runner
- updates hosts in sequence
- if the runner itself needs a reboot, it writes a resume marker and reboots
- a boot-time resume timer picks up the state and sends the final health summary

Notifications:
- Slack webhook on start, reboot checkpoints, resume, and finish
- Discord webhook on start, reboot checkpoints, resume, and finish
- final health summary after completion

Deployment helper:
- `scripts/install_monthly_maintenance.sh` installs the service/timer pair on the runner and enables both timers

Webhook source of truth:
- Use `/Users/poovannanrajendran/Documents/GitHub/lloyds-market-news-digest/.env` on `automation-runner-01` when you want the shared Slack/Discord webhooks used by Lloyds alerts.
- The runner maintenance scripts accept both `ALERT_WEBHOOK_SLACK` / `ALERT_WEBHOOK_DISCORD` and `SLACK_WEBHOOK_URL` / `DISCORD_WEBHOOK_URL`.
- If you prefer a dedicated runner-only file, place the same values in `/srv/stacks/observability/scripts/schedule_guard.env` and `/srv/stacks/observability/scripts/monthly_maintenance.env`.
- Recommended sync helper: `scripts/sync_runner_alert_env.sh` copies the webhook values from the Lloyds `.env` into the runner env files.

## Post-Boot Verification Checklist
After each boot or reboot, check:

### Host Layer
- Host responds to ping and SSH.
- Time sync is healthy.
- Storage mounts are present.
- No obvious boot errors in system logs.

### Proxmox Specific
- `pveproxy` is running.
- `pvedaemon` is running.
- VMs and LXCs are in the expected state.
- Backup jobs still exist and the schedule is intact.

### VM / Service Layer
- Docker daemon is running on `docker-host-01`.
- Compose stacks are up and the expected containers are healthy.
- `ced-app` is running, its internal cron is present, and it can reach the shared PostgreSQL service.
- Grafana / Prometheus / Alertmanager respond on the runner.
- OpenClaw gateway is running and reachable on the AI node.
- YouTube sync timer is active and the next run is scheduled.

### Application Layer
- Internal URLs respond:
  - Outline
  - Authentik
  - Nextcloud
  - Portainer
  - Jenkins
  - Grafana
  - Prometheus
  - Alertmanager
  - OpenClaw control UI
- Vercel and GitHub Pages dashboards show green or expected states.

### Data Layer
- Local Postgres databases are accepting connections.
- All PostgreSQL containers on VM `100` and VM `103` have a successful logical dump predating the `02:15` PBS snapshot.
- Logical dump retention matches PBS: latest 7, weekly 4, and monthly 6.
- MongoDB Atlas connectivity is confirmed.
- Supabase connectivity is confirmed if enabled.

### Observability Layer
- Dashboard `HomeServer Health` loads.
- Dashboard `Vercel + Lloyds Pages` loads.
- No unexpected alert storm is present.
- Collector metrics are fresh.

## Safe Reboot Rule
- Only reboot when needed.
- If `/var/run/reboot-required` exists, treat that as the reboot trigger for the host.
- If the marker does not exist, avoid rebooting unless the update path explicitly requires it.

## Notes
- Keep this checklist updated whenever new hosts, timers, or compose stacks are added.
- If a service has its own maintenance window or graceful shutdown requirement, document that in the service-specific runbook.

## Final Maintenance Verification
Last completed maintenance pass:
- Proxmox host `pve`: updated and rebooted
- `docker-host-01`: updated, rebooted, and Docker daemon restarted
- `automation-runner-01`: updated and rebooted; missing maintenance timers were restored on the correct host
- `ai-node-01`: updated, checked, no reboot required
- `pbs-01`: updated and healthy; no reboot required
- `jellyfin-01`: updated, mount present, and container healthy

Verified healthy after boot:
- Proxmox host reachable and guest inventory restored
- `docker-host-01` Compose services healthy
- `automation-runner-01` observability stack healthy
- `youtube-sync.timer` active on the runner
- `schedule-guard.timer` active on `automation-runner-01`
- `monthly-maintenance.timer` active on `automation-runner-01`
- `monthly-maintenance-resume.timer` active on `automation-runner-01`
- `openclaw-gateway.service` active on `ai-node-01`
- Proxmox backup job still present and scheduled
- `memex-runner.service` active on `automation-runner-01`
- `n8n` recovered after environment fix on `docker-host-01`

Guests intentionally left stopped:
- `102` `ubuntu-dev-01`
- `104` `media-01`

## Monthly Resume Flow
If `automation-runner-01` reboots during the monthly job:
- the coordinator writes `/srv/stacks/observability/state/monthly-maintenance.json`
- `monthly-maintenance-resume.timer` runs on boot
- the resume service checks for the marker and calls the main script with `--resume`
- the state is cleared after the final summary is sent

## Recommended Future Order
For the next full-stack maintenance window, use this sequence:

1. Check current health and record uptime, timers, and running containers.
2. Upgrade the Proxmox host first if host packages or kernel updates are pending.
3. Reboot the Proxmox host if the update path requires it.
4. Upgrade `docker-host-01`, then wait for Docker and compose stacks to settle.
5. Upgrade `automation-runner-01`, then verify `memex-runner` and timers.
6. Upgrade `ai-node-01`, then verify `openclaw-gateway`.
7. Upgrade `pbs-01`, then confirm the guest agent returns and the reboot marker is cleared.
8. Upgrade `jellyfin-01`, then confirm the host mount and container status.
9. Re-run package checks on every host and guest until all counts are `0`.
10. Re-run service checks for systemd units, cron schedules, and container health.

## Maintenance Report
See the dated report for the latest full pass:

- [Homeserver Maintenance Report (2026-07-12)](runbooks/homeserver-maintenance-report-2026-07-12.md)

## Schedule Drift Guard
There is also a daily schedule integrity check on `automation-runner-01`.

## Monitoring Cadence Note
- Vercel and GitHub Pages uptime probes are currently disabled to stop Edge Request usage.

Planned schedule:
- `*-*-* 06:30:00` via `schedule-guard.timer`

What it checks:
- `youtube-sync.timer` on `automation-runner-01`
- `monthly-maintenance.timer` and `monthly-maintenance-resume.timer` on `automation-runner-01`
- `openclaw-weekly-update.timer`, `ai-node-weekly-os-update.timer`, and `ai-node-conditional-reboot.timer` on `ai-node-01`
- the `youtube_enrichment/run_enrichment.sh` cron entry on `ai-node-01`
- the `nextcloud-cron` container on `docker-host-01`

Behavior:
- sends Slack/Discord notifications if any schedule is missing
- prints a full status summary when all checks pass

Deployment helper:
- `scripts/install_schedule_guard.sh` installs the service/timer pair on the runner and enables the timer
