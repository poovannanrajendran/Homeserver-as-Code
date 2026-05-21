# Homeserver Maintenance Report

Date: 2026-05-21

## Scope

This maintenance pass covered the full Proxmox homelab stack:

- Proxmox host
- VM guests
- LXC guests
- Docker host workloads
- systemd services
- cron / timer schedules

## Work Performed

### Proxmox Host

- Ran package refresh and full upgrade on the host.
- Rebooted the host after the kernel and Proxmox stack upgrade.
- Confirmed the new kernel is active after reboot.

### Docker Host VM `docker-host-01`

- Ran package refresh and upgrade.
- Rebooted the VM after upgrade.
- Re-validated the Docker daemon and container stack after boot.
- Fixed the `n8n` restart loop by restoring the missing database env interpolation values in the live compose env.

### AI Node VM `ai-node-01`

- Ran package refresh and upgrade.
- Confirmed no reboot was required.
- Verified OpenClaw gateway service state after the Proxmox reboot.

### Automation Runner VM `automation-runner-01`

- Ran package refresh and upgrade.
- Rebooted the VM after upgrade.
- Verified the `memex-runner` systemd service after boot.
- Verified the timer inventory after boot.

### PBS VM `pbs-01`

- Ran package refresh and upgrade through the guest agent.
- Rebooted the VM after upgrade.
- Confirmed the guest agent came back and the reboot marker cleared.

### Jellyfin LXC `jellyfin-01`

- Ran package refresh and upgrade.
- Confirmed the host mount for `/mnt/usb-4tb` was present again.
- Restarted the container and confirmed it is running.

## Verified Results

### Proxmox Host

- Hostname: `pve`
- Running kernel: `7.0.2-6-pve`
- Proxmox VE: `9.2.0`
- `pve-manager`: `9.2.2`

### VM / LXC Status

- `100 docker-host-01` running
- `101 ai-node-01` running
- `103 automation-runner-01` running
- `105 pbs-01` running
- `106 jellyfin-01` running

### Docker Host

- `docker` systemd service: active
- Core containers: running
- `n8n`: stable after the env fix
- `outline`, `authentik`, `postgres`, `mariadb`, `mongo`, `grafana`, `prometheus`, `cadvisor`, `jenkins`, `nginx`, `qdrant`, `nextcloud`: running

### AI Node

- `openclaw-gateway`: active

### Automation Runner

- `memex-runner`: active
- timers present and scheduled, including:
  - `youtube-sync.timer`
  - `apt-daily.timer`
  - `apt-daily-upgrade.timer`
  - `logrotate.timer`
  - `sysstat-collect.timer`
  - `sysstat-summary.timer`
  - `man-db.timer`
  - `fwupd-refresh.timer`

### Packages

- Proxmox host: `0` upgradable packages
- `docker-host-01`: `0` upgradable packages
- `ai-node-01`: `0` upgradable packages
- `automation-runner-01`: `0` upgradable packages
- `pbs-01`: `0` upgradable packages
- `jellyfin-01`: `0` upgradable packages

## Notable Fixes

- Recreated the `n8n` container after copying `N8N_DB_NAME`, `N8N_DB_USER`, and `N8N_DB_PASSWORD` into the platform env used by Compose interpolation.
- Confirmed the crash loop was caused by blank DB credentials in the live container environment.

## Future Maintenance Order

Use this sequence for the next full-stack update window:

1. Check current health and record the live state.
2. Upgrade the Proxmox host first if kernel or host packages are pending.
3. Reboot the Proxmox host if required.
4. Upgrade `docker-host-01` and let the container stack recover.
5. Upgrade `automation-runner-01` and verify systemd timers.
6. Upgrade `ai-node-01` and verify OpenClaw gateway health.
7. Upgrade `pbs-01` and confirm the guest agent comes back.
8. Upgrade `jellyfin-01` and verify the host mount plus container status.
9. Re-check Docker containers, systemd services, and timer schedules after all reboots.
10. Clear any package backlog such as `snapd` or other low-risk guest updates.

## Suggested Verification Commands

```bash
ssh root@192.168.1.250 'pveversion -v | head -n 8; qm list; pct list'
ssh labadmin@192.168.1.20 'systemctl is-active docker; docker ps --format "table {{.Names}}\t{{.Status}}"'
ssh labadmin@192.168.1.24 'systemctl is-active openclaw-gateway'
ssh labadmin@192.168.1.30 'systemctl is-active memex-runner; systemctl list-timers --all --no-pager | sed -n "1,20p"'
ssh root@192.168.1.250 'qm guest exec 105 -- bash -lc "hostname; uptime -p; test -f /var/run/reboot-required && echo REBOOT_REQUIRED || true"'
ssh root@192.168.1.250 'pct status 106'
```

