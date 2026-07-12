# Purpose: FinOSafe Media Platform

## 1. Why this exists

FinOSafe needs a standalone platform that sits beside the Paperclip company, not inside it.

Paperclip should remain the governance and agent-orchestration layer for:

- company roles
- task assignment
- approvals
- audited agent activity

The new platform should own the operational media stack for:

- channel and video analytics
- content production state
- render and publishing pipelines
- reusable internal APIs
- asset and artifact tracking

This separation keeps the system clean. Paperclip decides what work should happen. The media platform records what was produced, what was published, and how it performed.

## 2. Core problem

Today, the FinOSafe operating model is split across:

- YouTube Studio for channel metrics
- Paperclip tasks for content work
- ad hoc scripts and docs for pipeline ideas

That is workable for experimentation, but weak for operations. It lacks:

- one source of truth for channel and video stats
- one place to track script-to-publish pipeline state
- one API layer that later products can reuse
- one audit trail for jobs, retries, failures, and artifacts

## 3. Product goal

Create a standalone internal platform on the Proxmox home server that gives FinOSafe:

- a central API surface for media and analytics workloads
- a dashboard for channel health, video performance, and pipeline status
- a job system for sync, render, upload, and retry workflows
- a data model that supports future projects beyond FinOSafe
- a deployable Docker stack with persistent storage and controlled upgrade paths

## 4. Recommended shape

Build this as a separate project in the homelab, but keep it in the same repository for now until the boundaries stabilise.

Recommended structure:

- `apps/web`: `Next.js` dashboard and operator UI
- `apps/api`: `NestJS` internal API
- `workers/`: background jobs for sync, render, publish, enrichment
- `packages/`: shared types, schemas, SDKs, and UI primitives

This gives fast dashboard delivery without forcing the whole platform into one oversized frontend codebase.
It also maps cleanly to a `Docker Compose` deployment with service-level persistent volumes.

## 5. Recommended stack

- Frontend: `Next.js` with TypeScript
- API: `NestJS` with TypeScript
- Database: `PostgreSQL`
- Queue: `Redis` + `BullMQ`
- Object storage: `MinIO`
- Video/render workers: Python or Node, chosen per toolchain
- Deployment: `Docker Compose`
- Reverse proxy: `Caddy` or `Traefik`

Deployment expectation:

- the stack runs as a standalone `Docker Compose` project on the homelab
- stateful services use persistent volumes or bind mounts
- the platform supports in-place service upgrades with rollback discipline
- database and object storage data survive container recreation and image refreshes

## 6. Design principles

- Keep the dashboard and the internal API separate even if both are in one project.
- Treat YouTube as an external system of record, not as the application database.
- Store metric snapshots over time rather than only current values.
- Model every pipeline step as a state transition with auditability.
- Design new APIs as reusable platform APIs, not FinOSafe-only endpoints.
- Treat persistence, upgrades, backup, and restore as first-class platform requirements.

## 7. Near-term scope

The first release should focus on three capabilities:

- channel and video stats ingestion
- script-to-publish pipeline tracking
- operator dashboard for channel health, videos, runs, and failures

## 8. Future expansion

This platform should be able to absorb future modules without redesigning the core:

- thumbnail generation and variant testing
- captioning and subtitle workflows
- cross-posting APIs for LinkedIn, X, Reddit, Telegram, Discord
- document and asset storage for briefs, scripts, transcripts, thumbnails, and rendered videos
- benchmark scoring across content pillars
- multi-brand support beyond FinOSafe
- AI-assisted review and compliance checks

It should also plug into the existing homelab observability stack:

- Prometheus for service and application metrics
- Grafana for dashboards and operator visibility
- active service checks for API, web, workers, queue, database, and object storage
- linked visibility from the existing homeserver dashboards on `automation-runner-01`

## 9. Success condition

The platform is successful when FinOSafe can answer these questions from one place:

- What did we publish?
- What is in progress?
- What failed?
- Which videos are actually driving growth?
- Which content themes should we do more of next?
