# Homeserver Maintenance Report

Date: 2026-07-12

## Scope

This maintenance pass covered the full Proxmox homelab stack after the hypervisor was powered back on:

- Proxmox host
- VM guests
- LXC guests
- Docker host workloads
- systemd services and timers
- post-reboot verification and schedule restoration

## Work Performed

### Proxmox Host

- Ran package refresh and full upgrade on the host.
- Rebooted the host after the kernel and Proxmox stack upgrade.
- Confirmed the new kernel is active after reboot.

### Docker Host VM `docker-host-01`

- Ran package refresh and upgrade.
- Rebooted the VM after upgrade.
- Revalidated the Docker daemon and compose stack recovery after boot.
- Refreshed the active compose stacks, including databases, platform services, Nextcloud, Outline, Authentik, Portainer, SMTP relay, and `ced-app`.

### AI Node VM `ai-node-01`

- Ran package refresh and upgrade.
- Confirmed no reboot was required.
- Verified OpenClaw gateway health and the current OpenClaw update state.

### Automation Runner VM `automation-runner-01`

- Ran package refresh and upgrade.
- Verified `memex-runner.service` after boot.
- Restored the documented schedule integrity timers on the correct host:
  - `schedule-guard.timer`
  - `monthly-maintenance.timer`
  - `monthly-maintenance-resume.timer`

### PBS VM `pbs-01`

- Ran package refresh and upgrade through the guest agent.
- Confirmed the guest stayed healthy and no reboot was required.

### Jellyfin LXC `jellyfin-01`

- Ran package refresh and upgrade.
- Confirmed the media mount remained present.
- Verified the container remained healthy after the host reboot.

## Verified Results

### Proxmox Host

- Hostname: `pve`
- Running kernel: updated to the current Proxmox kernel after reboot
- Guest inventory: restored

### VM / LXC Status

- `100 docker-host-01` running
- `101 ai-node-01` running
- `103 automation-runner-01` running
- `105 pbs-01` running
- `106 jellyfin-01` running

### Docker Host

- `docker` systemd service: active
- Core containers: running
- `ced-app`: running
- `outline`, `authentik`, `postgres`, `mariadb`, `mongo`, `grafana`, `prometheus`, `cadvisor`, `jenkins`, `nginx`, `qdrant`, `nextcloud`: running

### AI Node

- `openclaw-gateway`: active
- OpenClaw update state: already at the latest available registry version

### Automation Runner

- `memex-runner`: active
- `youtube-sync.timer`: active
- `schedule-guard.timer`: restored and active
- `monthly-maintenance.timer`: restored and active
- `monthly-maintenance-resume.timer`: restored and enabled

### Packages

- All managed hosts and guests were upgraded during this pass.
- No host needed a second reboot after verification.

## Notable Fixes

- Restored the missing automation-runner maintenance timers on `automation-runner-01`.
- Corrected the initial misplacement of those timers on `ai-node-01`.
- Confirmed the maintenance scheduler now lives on the documented runner host, `192.168.1.30`.

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

## Suggested Verification Commands

```bash
ssh root@192.168.1.250 'pveversion -v | head -n 8; qm list; pct list'
ssh labadmin@192.168.1.20 'systemctl is-active docker; docker ps --format "table {{.Names}}\t{{.Status}}"'
ssh labadmin@192.168.1.24 'systemctl is-active openclaw-gateway'
ssh labadmin@192.168.1.30 'systemctl is-active memex-runner; systemctl list-timers --all --no-pager | sed -n "1,20p"'
ssh root@192.168.1.250 'qm guest exec 105 -- bash -lc "hostname; uptime -p; test -f /var/run/reboot-required && echo REBOOT_REQUIRED || true"'
ssh root@192.168.1.250 'pct status 106'
```
