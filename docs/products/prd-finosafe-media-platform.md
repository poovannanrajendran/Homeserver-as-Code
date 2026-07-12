# Product Requirements Document: FinOSafe Media Platform

## 1. Product summary

Build a standalone internal media operations platform for FinOSafe that measures YouTube performance, manages content production state, and exposes reusable APIs for future media automation.

This platform is separate from Paperclip. Paperclip remains the control plane for company and agent workflow. The media platform becomes the operational plane for media data, assets, and publishing.

## 2. Objectives

- Centralise FinOSafe media APIs in one homelab platform
- Provide a fast dashboard for channel, video, and pipeline visibility
- Track content from brief to publish to performance review
- Preserve full run history, failures, retries, and artifacts
- Create reusable foundations for future APIs and products

## 3. Non-objectives

- Replacing Paperclip company governance
- Building a public-facing product
- Full social media suite in v1
- Full video generation autonomy in v1
- Re-implementing all YouTube Studio features

## 4. Users

- Primary: Poovi as operator and owner
- Secondary: Paperclip agents acting through controlled APIs
- Future: other internal brands, analysts, and automation workers

## 5. Recommended architecture

### 5.1 Platform choice

Use a standalone TypeScript-first platform project.

Recommended layout:

- `apps/web`: `Next.js` dashboard, auth, operator actions
- `apps/api`: `NestJS` internal API for stats, videos, artifacts, runs, and publishing
- `workers/`: scheduled and queue-driven jobs
- `packages/shared`: types, validation schemas, shared SDKs

Deployment model:

- one standalone `Docker Compose` project for the platform
- persistent storage for `PostgreSQL`, `Redis` durability where configured, and `MinIO`
- upgrade flow based on image refresh, schema migration, health verification, and rollback if needed

### 5.2 Why this is the right tradeoff

`Next.js` is the fastest route to dashboarding and internal tools.

`NestJS` is the cleaner long-term API boundary once the platform grows beyond simple dashboard endpoints. It avoids collapsing job orchestration, ingest APIs, internal admin workflows, and UI concerns into a single web app.

This is intentionally more structured than using only `Next.js` route handlers, because the platform will expand into multiple APIs and background workflows.

## 6. Functional requirements

### 6.1 Channel analytics

The platform must:

- ingest FinOSafe channel overview metrics
- snapshot subscriber count, total views, video count, and reporting windows
- record time-based changes for trend analysis
- surface 7-day and 28-day summaries in the dashboard

Examples of tracked metrics:

- current subscribers
- subscriber delta
- views over period
- watch time over period
- upload count over period

### 6.2 Video performance

The platform must:

- ingest metadata for published videos
- snapshot performance metrics over time
- normalise performance by publish age
- support filtering by content type, topic pillar, and status

Examples of tracked metrics:

- title
- video ID
- published at
- views
- likes
- comments
- watch time
- impressions
- click-through rate
- retention summary when available

### 6.3 Content pipeline tracking

The platform must track content items through these states:

- idea
- brief_ready
- script_draft
- script_approved
- assets_in_progress
- render_ready
- uploaded
- scheduled
- published
- reviewed
- failed
- cancelled

Each state transition must be timestamped and auditable.

### 6.4 Artifact management

The platform must store and reference artifacts linked to content items:

- briefs
- script versions
- thumbnails
- captions
- voiceover files
- render outputs
- final published metadata

Artifact binaries should live in object storage. Metadata should live in Postgres.

### 6.5 Publishing workflows

The platform must support:

- draft upload preparation
- metadata assembly
- scheduled publishing
- post-publish metric sync
- failure capture and retry

The platform may defer full automated publishing in v1, but the data model must support it.

### 6.6 Job and run tracking

Every worker or scheduled task must record:

- run start and end
- status
- duration
- trigger type
- error summary
- linked entity IDs
- retry count

### 6.7 Internal APIs

The first API set should include:

- `GET /projects`
- `GET /projects/:slug/summary`
- `GET /projects/:slug/channel-snapshots`
- `GET /projects/:slug/videos`
- `GET /projects/:slug/videos/:id`
- `GET /projects/:slug/content-items`
- `POST /projects/:slug/content-items`
- `POST /projects/:slug/content-items/:id/transitions`
- `GET /projects/:slug/runs`
- `GET /projects/:slug/artifacts`

Internal worker endpoints should also exist for:

- metric sync start/complete
- publish start/complete
- render start/complete
- retry scheduling

## 7. Data model requirements

Core tables should include:

- `projects`
- `channels`
- `channel_metric_snapshots`
- `videos`
- `video_metric_snapshots`
- `content_items`
- `content_item_transitions`
- `artifacts`
- `job_runs`
- `job_run_metrics`
- `audit_events`

Key design rules:

- every domain record must be project-scoped
- snapshots must be append-only unless explicitly corrected
- worker writes must be idempotent
- artifacts must support versioning

## 8. Dashboard requirements

The dashboard should provide:

- portfolio/project overview
- FinOSafe channel health
- published video table
- content pipeline board
- run history and failures
- artifact drill-down

Initial dashboard pages:

- `Overview`
- `Videos`
- `Pipeline`
- `Runs`
- `Artifacts`
- `Settings`

## 9. Operational requirements

- deployable on the Proxmox homelab using `Docker Compose`
- stateful services must use persistent volumes or bind mounts
- container replacement must not lose database or artifact state
- the stack must support controlled upgrades and documented rollback
- secrets managed through env files or host secret injection
- structured logs for all services
- Prometheus-compatible health and metrics endpoints
- queue-based retries for async workflows

## 10. Security requirements

- internal-only access in v1
- authenticated operator access for the dashboard
- service-token protection for worker endpoints
- audit logs for all mutations
- no secrets stored in repository-tracked files

## 11. Observability requirements

- expose health endpoints for `web`, `api`, and worker services
- emit Prometheus-compatible application metrics
- expose active service status for critical dependencies:
  - `PostgreSQL`
  - `Redis`
  - `MinIO`
  - background workers
  - queue processing
- integrate with the existing observability stack on `automation-runner-01`
- surface the platform in the current Grafana estate, including the existing homeserver dashboard or a linked companion dashboard
- support runner-side service checks similar to the existing `host_checks.sh` model where useful

Examples of expected visibility:

- service up/down state
- API health
- queue depth
- failed jobs
- last successful sync time
- database connectivity
- object storage availability

## 12. Delivery phases

### Phase 1: Core platform

- bootstrap `Next.js` dashboard
- bootstrap `NestJS` API
- provision `Postgres`, `Redis`, `MinIO`
- implement auth, projects, runs, audit skeleton
- define persistent volume layout and upgrade procedure
- wire health endpoints and Prometheus metrics from day one

### Phase 2: FinOSafe analytics

- add channel snapshot ingestion
- add video metadata and metric snapshots
- build channel overview and video table

### Phase 3: Content pipeline

- add content item model and state machine
- add artifact tracking
- add pipeline board and content detail page

### Phase 4: Publishing automation

- add upload metadata assembly
- add scheduled publish workflows
- add post-publish sync and failure handling

### Phase 5: Expansion

- add cross-platform APIs
- add richer analytics and experiment tracking
- add multi-brand support

## 13. Future expansion plan

The platform should support future modules for:

- newsletter and blog publishing
- LinkedIn, X, Reddit, Telegram, and Discord cross-posting
- thumbnail A/B testing
- content idea scoring
- agent-facing SDKs
- external reporting and exports
- approval workflows tied back into Paperclip
- other Poovi-owned media or data brands

## 14. Success metrics

- one operator dashboard replaces manual cross-checking across YouTube Studio, docs, and scripts
- all published videos appear in the platform with snapshot history
- all pipeline jobs are auditable
- the content team can identify winning topics and underperforming formats
- onboarding a second media project does not require redesigning the platform
- the platform appears in Prometheus and Grafana with active health checks and drill-down visibility
