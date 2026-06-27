# Tasks: FinOSafe Media Platform

## 1. Project setup

- Create a standalone platform workspace within the repository
- Define the monorepo structure for `apps`, `workers`, and `packages`
- Add baseline docs for local development, deployment, and secrets handling
- Define environment variable conventions for web, API, workers, and infrastructure

## 2. Platform foundation

- Bootstrap `apps/web` with `Next.js` and TypeScript
- Bootstrap `apps/api` with `NestJS`
- Add shared package for DTOs, schemas, and typed clients
- Add linting, formatting, and test baselines
- Add Docker Compose for `web`, `api`, `postgres`, `redis`, `minio`
- Define persistent volume and bind-mount strategy for stateful services
- Define upgrade and rollback workflow for container and schema changes

## 3. Identity and access

- Define internal auth model for operator login
- Define service authentication for worker-to-API calls
- Define project-scoped RBAC model
- Add audit event recording for all mutations

## 4. Data model and persistence

- Define initial Postgres schema for projects, channels, videos, snapshots, runs, content items, transitions, artifacts, and audit events
- Add migration tooling
- Add seed data support for FinOSafe
- Add retention policy rules for snapshots and job logs

## 5. Channel analytics module

- Implement channel snapshot ingestion flow
- Implement channel summary endpoints
- Store current and historical channel metrics
- Build dashboard cards for subscribers, views, videos, and 28-day deltas
- Add sync job scheduling and run tracking

## 6. Video analytics module

- Implement video metadata ingestion
- Implement video metric snapshot ingestion
- Add video list and detail endpoints
- Add dashboard filters for publish date, content type, and status
- Add baseline comparisons by publish age

## 7. Content pipeline module

- Define content item entity and state machine
- Implement transition rules and validation
- Store brief, script, thumbnail, and caption metadata
- Build operator pipeline board
- Add content detail page with timeline and linked artifacts

## 8. Artifact storage module

- Provision `MinIO` bucket layout
- Define artifact metadata schema
- Implement upload and retrieval APIs
- Add versioning rules for briefs, scripts, thumbnails, captions, and renders
- Add artifact links into content and video pages

## 9. Job orchestration and workers

- Define worker interface contract for sync, render, publish, and retry jobs
- Add `BullMQ` queues and retry policy
- Implement run tracking lifecycle hooks
- Add dead-letter visibility for failed jobs
- Add worker health and liveness endpoints

## 10. Publishing module

- Define upload preparation workflow
- Define scheduled publish workflow
- Implement metadata assembly and validation
- Add publish result capture and failure handling
- Add post-publish sync trigger

## 11. Observability

- Add structured logging across `web`, `api`, and workers
- Expose service health endpoints
- Expose Prometheus-compatible metrics
- Add dashboards or panels for queue depth, job failures, and sync freshness
- Add active service checks for API, web, workers, Postgres, Redis, and MinIO
- Define how platform metrics feed into the existing Prometheus and Grafana stack on `automation-runner-01`
- Link platform health into the current homeserver dashboard or add a clearly linked companion dashboard
- Define runner-side checks or textfile metrics if host-level visibility is required

## 12. Deployment and operations

- Define Compose deployment for homelab environments
- Add backup expectations for Postgres and object storage
- Add restore runbook
- Add update and rollback procedure
- Document persistent storage paths and recovery expectations
- Document post-upgrade verification checks, including service health and Prometheus target status

## 13. MVP acceptance criteria

- FinOSafe appears as a seeded project in the platform
- Channel overview metrics are visible in the dashboard
- Published video records are queryable through API and UI
- Content items can move through a tracked pipeline
- Worker runs, failures, and retries are visible
- Artifacts are stored and linked to content items
- The platform services are running under `Docker Compose` with persistent state
- Prometheus can scrape the platform and Grafana shows service health and key metrics

## 14. Suggested issue breakdown

### Epic A: Bootstrap the platform

- Create workspace layout
- Add CI, linting, and base Compose stack
- Add local development docs

### Epic B: Core domain and auth

- Implement projects, roles, runs, and audit events
- Add seed data and migration flow

### Epic C: FinOSafe analytics

- Channel snapshot ingestion
- Video ingestion and metric snapshots
- Overview and video pages

### Epic D: Content production tracking

- Content item state machine
- Artifact model
- Pipeline board and detail views

### Epic E: Publishing automation

- Upload metadata flow
- Publish scheduling
- Post-publish sync and run management

### Epic F: Expansion interfaces

- Cross-posting API foundation
- External export/reporting APIs
- Multi-brand project onboarding flow

## 15. Future artifacts and APIs to plan for now

- `brief-service`
- `script-service`
- `thumbnail-service`
- `render-service`
- `publish-service`
- `social-distribution-service`
- `reporting-export-service`
- `agent-sdk`

These do not all need implementation in v1, but the platform boundaries should assume they will exist.
