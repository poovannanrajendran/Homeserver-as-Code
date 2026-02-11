# Documentation Index

This is the primary navigation page for the **Homeserver-as-Code** documentation set.

## Recommended Reading Order
1. [Requirements and Specification](requirements-specification.md)
2. [Implementation Plan](implementation-plan.md)
3. [Architecture (Single Node)](architecture.md)
4. [Visual Diagrams](diagrams.md)
5. [Operations Runbook](runbooks.md)

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

## Contributor Notes
- Keep this index updated when new docs are added.
- Prefer documentation ranges for network examples (`192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`).
- Do not add real credentials, internal DNS names, or private infrastructure identifiers.
