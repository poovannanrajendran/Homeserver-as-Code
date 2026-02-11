# Implementation Plan

## Phase 1: Base Host
- Validate host networking, NTP, storage pools
- Confirm cloud-init template integrity

## Phase 2: Core VMs
- Create docker host, automation runner, AI node, media VM, PBS VM
- Apply baseline hardening (updates, timezone, firewall policy)

## Phase 3: Compose Stacks
- Deploy databases first
- Deploy platform services (n8n/Jenkins/Nginx)
- Deploy observability (Prometheus/Grafana)
- Deploy Nextcloud and media workloads

## Phase 4: Backup + Recovery
- Configure PBS datastore
- Schedule nightly VM backups
- Test restore workflow on a non-production VM

## Phase 5: Remote Access Hardening
- Enable Tailscale on service VMs
- Move admin surfaces to Tailscale where practical
- Reduce unnecessary LAN exposure in controlled steps
