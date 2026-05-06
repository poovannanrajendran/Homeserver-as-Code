# Documentation Index

This is the primary navigation page for the **Homeserver-as-Code** documentation set.

## Recommended Reading Order
1. [Requirements and Specification](requirements-specification.md)
2. [Implementation Plan](implementation-plan.md)
3. [Architecture (Single Node)](architecture.md)
4. [Visual Diagrams](diagrams.md)
5. [Operations Runbook](runbooks.md)
6. [Outline (Family Wiki)](outline.md)
7. [HomeServer Health Monitoring](observability-homeserver-health.md)
8. [Update and Reboot Maintenance Checklist](update-maintenance-checklist.md)
9. [Vercel Agent Skills for Codex](vercel-agent-skills.md)
10. [OpenClaw Memory and Second Brain Plan](openclaw-memory-secondbrain-plan.md)
11. [Gemini-CLI Memex OpenClaw Handoff](gemini-cli-memex-openclaw-handoff.md)
12. [Agentic Architecture Implementation](agentic-architecture-implementation.md)

## What Each Document Covers

## 1) Requirements and Specification
Defines the target outcomes and constraints:
- project objective
- workload and platform requirements
- network, security, and persistence standards
- acceptance criteria

## 2) Implementation Plan
Defines the delivery sequence:
- phased rollout model
- task breakdown per phase
- validation gates and acceptance checks

## 3) Architecture
Defines structural decisions:
- single-node Proxmox model
- VM role separation
- remote access model

## 4) Visual Diagrams
Provides operational visuals for:
- platform architecture
- LAN/Tailscale access paths
- Docker service connectivity
- storage and backup flow

## 5) Operations Runbook
Provides day-2 operational procedures:
- compose updates
- backup preflight
- common validation commands

## 6) HomeServer Health Monitoring
Operational reference for:
- Grafana dashboard access
- Prometheus/Alertmanager health
- monitored endpoints (Proxmox/VMs/apps/DBs)
- alert routing and troubleshooting

## 7) Update and Reboot Maintenance Checklist
Operational reference for:
- package/update inventory across Proxmox, VMs, and Docker hosts
- what to check before rebooting
- what to verify after boot
- reboot ordering for long-delayed maintenance

## 8) Vercel Agent Skills for Codex
Reference for:
- installed Vercel skill bundle
- token-based Vercel CLI usage
- practical limitations versus the original Vercel plugin
- when to use the skills for deploy/link workflows

## 9) OpenClaw Memory and Second Brain Plan
Reference for:
- OpenClaw live memory setup
- Qdrant and Mem0 deployment
- Memex MCP bridge
- agent instruction deployment
- known schema caveats

## 10) Gemini-CLI Memex OpenClaw Handoff
Copy-paste handoff for applying the Memex runner/API/ingest fixes in the Memex repository.

## 11) Agentic Architecture Implementation
Implementation guide for splitting the system into:
- Hermes-style execution
- Paperclip-style governance
- `docs/paperclip-operational-status.md`
- phased rollout and validation

## Contributor Notes
- Keep this index updated when new docs are added.
- Prefer documentation ranges for network examples (`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`).
- Do not add real credentials, internal DNS names, or private infrastructure identifiers.


## Product Docs
- [Multi-Project Dashboard Architecture](products/multi-project-dashboard-architecture.md)
- [PRD: YouTube Liked Videos](products/prd-youtube-liked-videos.md)
- [PRD: London Lloyds News Digest](products/prd-london-lloyds-news-digest.md)
- [SQL Starter Schema](products/sql-starter-schema.md)
- [API Contract](products/api-contract.md)
- [Implementation Backlog](products/implementation-backlog.md)
- [Data Model: YouTube + Lloyds](products/data-model-youtube-and-lloyds.md)
