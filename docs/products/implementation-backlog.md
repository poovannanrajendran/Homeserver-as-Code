# Implementation Backlog (Phased)

## Phase 0: Foundations
- Provision `dashboard-web`, `dashboard-api`, `dashboard-db`, `redis`.
- Configure OIDC and base RBAC.
- Add migration framework and CI checks.

Exit criteria:
- User can log in and view empty project list.
- Health checks + basic observability available.

## Phase 1: Platform Core
- Implement `projects`, `runs`, `audit` APIs.
- Build shared React shell (project switcher, global filters, nav).
- Add run timeline and audit table components.

Exit criteria:
- Platform can display run/audit data for a seeded test project.

## Phase 2: YouTube Integration
- Integrate current V5 worker run logs into `job_runs`/metrics.
- Build YouTube views: overview, videos table, run diagnostics.
- Add controlled transcript backfill trigger endpoint.

Exit criteria:
- Operators can monitor hourly sync and execute one-time backfill from UI/API.

## Phase 3: Lloyds News Integration
- Implement source registry and ingestion pipeline.
- Add enrichment + digest generation jobs.
- Build news explorer and digest history pages.

Exit criteria:
- Daily digest generated and visible with source lineage.

## Phase 4: Reliability and Controls
- Alerts and SLA widgets.
- Retry/dead-letter tooling for failed jobs.
- Audit retention and archive process.

Exit criteria:
- Alerting + on-call playbooks validated in test failures.

## Phase 5: Hardening and Scale
- Performance tuning and index improvements.
- Add caching layer for heavy dashboard queries.
- Add role matrix tests and security review.

Exit criteria:
- Meets latency and availability goals under expected load.
