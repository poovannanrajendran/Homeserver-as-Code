# Multi-Project Dashboard Platform Architecture

## 1. Purpose
Define a scalable architecture for a single dashboard platform that can host multiple projects (starting with YouTube Liked Videos and London Lloyds News Digest), with strong auditability, role-based access, and operational reliability.

## 2. Goals
- One shared platform for many data products.
- Fast, filterable UI for project KPIs, runs, and audit trails.
- Strong tenancy boundaries at the data model and API layer.
- Easy onboarding of new projects with minimal boilerplate.
- Clear observability and failure handling.

## 3. Recommended Stack
- Frontend: Next.js (React + TypeScript)
- Backend API: NestJS (TypeScript) or Next.js API routes for smaller scope
- Database: PostgreSQL (primary analytical and audit store)
- Queue/Scheduler: BullMQ + Redis (or platform cron + job workers)
- Data ingestion workers: Python (project-specific ETL/transcript/news pipelines)
- AuthN/AuthZ: OIDC (Auth0/Keycloak/Authentik) + RBAC in app DB
- Observability: Prometheus + Grafana + structured JSON logs

Rationale:
- React/Next gives the best dashboard UX velocity.
- Node/TypeScript keeps dashboard/API contracts strongly typed.
- Python remains best for ingestion and NLP-heavy jobs.

## 4. High-Level Architecture
- `dashboard-web` (Next.js): UI, SSR/ISR pages, project views.
- `dashboard-api` (Node): unified project APIs, permissions, audit APIs.
- `dashboard-db` (Postgres): metadata, metrics, runs, audit events.
- `worker-youtube` (Python): sync liked videos, transcripts, stats.
- `worker-news-digest` (Python): fetch/classify/summarize Lloyds news.
- `event-bus/queue` (Redis+BullMQ or equivalent): async jobs and retries.
- `object-store` (optional): store large artifacts (raw JSON, exports, attachments).

## 5. Logical Tenancy Model
Use project-scoped partitioning rather than separate apps.

### 5.1 Core dimensions
- `project`: product identity (`youtube_liked_videos`, `lloyds_news_digest`, etc.)
- `environment`: `dev`, `staging`, `prod`
- `source_system`: `youtube_api`, `rss`, `scraper`, `manual`

### 5.2 Access boundaries
- Every domain table includes `project_id`.
- API enforces project scope from user claims + role bindings.
- Audit events always include `project_id`, actor, action, and object.

## 6. Data Model (PostgreSQL)

### 6.1 Platform tables
- `projects(id, slug, name, owner_team, status, created_at)`
- `users(id, email, display_name, auth_subject, created_at)`
- `roles(id, name)`
- `user_project_roles(user_id, project_id, role_id)`

### 6.2 Execution and observability
- `job_runs(id, project_id, job_name, trigger_type, started_at, ended_at, status, duration_ms, error_summary)`
- `job_run_metrics(id, run_id, metric_key, metric_value_num, metric_value_text)`
- `alerts(id, project_id, severity, title, details, status, created_at, resolved_at)`

### 6.3 Audit
- `audit_events(id, project_id, actor_type, actor_id, action, resource_type, resource_id, before_json, after_json, metadata_json, created_at)`
- Indexes:
  - `(project_id, created_at desc)`
  - `(resource_type, resource_id, created_at desc)`
  - `(actor_id, created_at desc)`

### 6.4 Project extension tables
- YouTube-specific tables and Lloyds-specific tables remain separate domain schemas or prefixed tables, all linked to `project_id`.

## 7. API Design

### 7.1 API layers
- `GET /projects` and `GET /projects/:slug/summary`
- `GET /projects/:slug/runs` and `GET /projects/:slug/runs/:id`
- `GET /projects/:slug/audit`
- Domain endpoints, e.g.:
  - `/projects/youtube-likes/videos`
  - `/projects/lloyds-news/articles`

### 7.2 API standards
- Cursor-based pagination for large datasets.
- Time-range filters on every list endpoint.
- Idempotent write endpoints for worker upserts.
- Correlation IDs for all requests and job runs.

## 8. Frontend Information Architecture

### 8.1 Global areas
- Portfolio Overview
- Project Explorer
- Runs & Failures
- Audit Trail
- Alerts & SLA

### 8.2 Project workspace pattern
Each project page has the same tabs:
- `Overview`
- `Data`
- `Runs`
- `Audit`
- `Settings`

This gives a reusable shell and consistent operator workflow.

## 9. Audit and Compliance Patterns
- Every mutation emits an `audit_event` with before/after snapshot for critical entities.
- Job-level actions are also auditable (`run_started`, `run_completed`, `retry_triggered`, `manual_override`).
- Retention policy:
  - hot: 90 days in primary DB
  - warm/archive: 1+ year in object storage/export table

## 10. Scheduling and Reliability
- Worker jobs run per project schedule (hourly for YouTube sync, configurable windows for news digest).
- Retry policy:
  - transient errors: exponential backoff (max 3)
  - permanent errors: fail + alert
- Circuit breaker for unstable external sources.
- Dead-letter queue for exhausted retries.

## 11. Deployment Topology (Home Server Friendly)
- `automation-runner-01`: workers + scheduler + queue
- `docker-host-01`: dashboard-web, dashboard-api, redis, postgres
- Optional split if load grows: dedicated Postgres VM for dashboards

Current automation-runner DB exposure pattern:
- `automation-postgres` is published on `0.0.0.0:5432` for LAN clients.
- Workloads on the same host (for example Lloyds digest) still connect via `localhost:5432`.
- This dual requirement avoids breaking local runtime while enabling LAN tools and dashboard services.

## 12. Security
- Secrets only via env vars or secret manager, never committed.
- JWT/OIDC-based auth with short token TTL.
- Fine-grained RBAC:
  - `viewer`, `operator`, `owner`, `admin`
- Database roles:
  - app read/write user
  - migration user
  - read-only BI user

## 13. MVP Delivery Plan
1. Platform shell (projects, auth, runs, audit list)
2. YouTube project integration
3. Lloyds news project integration
4. Alerts and SLA pages
5. Export/reporting and archived audit retrieval

## 14. Key Decisions
- Use React/Node for platform UX and APIs.
- Keep Python for data pipelines.
- Use one shared Postgres with strict `project_id` scoping.
- Standardize project workspace tabs to reduce complexity.
