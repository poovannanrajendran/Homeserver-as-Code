# HomeServer Health Monitoring (Grafana + Prometheus + Alertmanager)

## Scope
This document captures the current monitoring setup for:
- Proxmox host health
- VM reachability/SSH checks
- App URL uptime (LAN + Vercel)
- Database health and size checks (local Postgres + Supabase + remote Postgres dependency)
- Qdrant authenticated readiness and Prometheus scrape status
- Disk usage checks
- Cron job inventory/coverage
- Alerting to email + Telegram

## Where It Runs
- Host: `automation-runner-01` (`192.168.1.30`)
- Stack path: `/srv/stacks/observability`

## Dashboard Access
- Grafana URL (LAN): `http://192.168.1.30:3000`
- Grafana admin user and password are supplied through `/srv/stacks/observability/.env`; no default password is committed
- Dashboard URL: `http://192.168.1.30:3000/d/homeserver-health/homeserver-health`
- Additional dashboard: `Vercel + Lloyds Pages` (`vercel-lloyds-pages`)
- Purpose: track all Vercel apps and the Lloyds GitHub Pages site in one view
- Live dashboard URL: `http://192.168.1.30:3000/d/vercel-lloyds-pages/vercel-2b-lloyds-pages`
- Browser-verified state: dashboard imported successfully and renders in logged-in Chrome
- The main stat cards have drilldown links to the underlying Prometheus queries.
- Use those links when a card is amber or red to inspect the exact failing endpoints.
- The dashboard also includes explicit `HTTP Drilldown Details` and `TCP Drilldown Details` tables under the summary cards.

## What Is Monitored

### Probe Cadence
- External Vercel/GitHub Pages probes: disabled
- Internal infrastructure TCP probes: every 1 minute
- Blackbox HTTP probe: every 1 minute
- The daily schedule guard remains enabled for schedule drift detection.

### Infrastructure
- Proxmox HTTPS: `https://192.168.1.250:8006`
- VM ping + SSH:
  - `192.168.1.20` (`docker-host-01`)
  - `192.168.1.24` (`ai-node-01`)
  - `192.168.1.30` (`automation-runner-01`)

### Application/Uptime URLs
- LAN services (`:3010`, `:9000`, `:5678`, etc.)
- Vercel apps, including:

### Databases
- Local Postgres (`lloyds_digest`): `<redacted; see local/private/observability-homeserver-health.md>`
- Local Postgres (`memex`): `<redacted; see local/private/observability-homeserver-health.md>`
- Remote dependency Postgres (`youtube_liked_videos`): `<redacted; see local/private/observability-homeserver-health.md>`
- Supabase Postgres: `<redacted; see local/private/observability-homeserver-health.md>`
- Mongo Atlas TCP check: `<redacted; see local/private/observability-homeserver-health.md>`
- Qdrant vector store: `192.168.1.20:6333`
  - Prometheus job: `qdrant`
  - Auth: bearer credentials file mounted at `/etc/prometheus/secrets/qdrant_api_key`
  - The host secret is `/srv/stacks/observability/prometheus/secrets/qdrant_api_key` on `automation-runner-01`; it must be owned/readable by the Prometheus container user (`nobody:nogroup`, mode `0400`).
  - Host-check metric: `obs_qdrant_http_up`
  - Health endpoint: `/readyz` or `/healthz`; do not use `/health`
  - Current Grafana option: dashboard ID `24603` ("Qdrant Dashboard (Prometheus metrics only)") for this Prometheus-only setup. If you later add `qdrant-exporter`, the richer Qdrant dashboards can be reconsidered.

### Disk + Cron
- Disk usage for `/` and `/var`
- Cron job counts:
  - local runner cron count
  - remote cron count probes (Proxmox + VMs)

## Metrics Produced by `host_checks.sh`
- `obs_proxmox_https_up`
- `obs_ping_up`
- `obs_ssh_up`
- `obs_postgres_query_ok`
- `obs_postgres_db_size_bytes`
- `obs_filesystem_used_percent`
- `obs_cron_jobs_total`
- `obs_mongo_atlas_tcp_up`
- `obs_supabase_configured`
- `obs_qdrant_http_up`
- `obs_health_collector_run_timestamp`

Collector files:
- Script: `/srv/stacks/observability/scripts/host_checks.sh`
- Env: `/srv/stacks/observability/scripts/host_checks.env`
- Output: `/srv/stacks/observability/textfile/host_checks.prom`
- Cron: every 5 minutes

## Alerting

### Rules (Prometheus)
File: `/srv/stacks/observability/prometheus/rules/homeserver-alerts.yml`

Configured alerts:
- `ProxmoxDown`
- `VmUnreachable`
- `DatabaseCheckFail`
- `DiskUsageHigh`

### Routing (Alertmanager)
Rendered config:
- `/srv/stacks/observability/alertmanager/alertmanager.yml`

Inputs:
- `/srv/stacks/observability/scripts/alertmanager.env`

Receivers:
- Email (SMTP relay via `192.168.1.20:1587`)
- Telegram (bot + chat id)

## Current Operational Notes
- Alert sender was changed to `hello@britaroma.com` so SMTP relay policy accepts outgoing alerts.
- Email delivery now passes relay checks (`status=sent` visible in `smtp-relay` logs).
- Telegram API delivery was validated; the bot token and chat ID remain in the ignored runtime environment.
- Monthly maintenance notifications are wired through Slack and Discord webhooks from the runner-side maintenance script.
- Amber/red cards are threshold states, not cosmetic:
  - amber means degraded or partially failing
  - red means failing or below the healthy threshold
- Current red/amber comes from aggregate probe health, not the Grafana password change.
- The new drilldown rows show the exact endpoints with `probe_success == 0`.
- The runner textfile collector must emit valid Prometheus exposition or node-exporter will drop the whole `host_checks.prom` file; the current `host_checks.sh` fixes quoted labels and duplicate filesystem series.

## Dashboard Import/Update (Important)
On this host, Grafana file-based datasource provisioning can fail with:
- `Datasource provisioning error: data source not found`

Use API-based import helper instead for catalog visibility:
```bash
/srv/stacks/observability/scripts/import_homeserver_dashboard.sh
```
If you need the drilldown links to appear immediately, re-import the dashboard JSON after copying the updated file into `/srv/stacks/observability/grafana/dashboards/homeserver-health.json`.
The `Vercel + Lloyds Pages` dashboard was imported the same way and verified in Chrome against:
`http://192.168.1.30:3000/d/vercel-lloyds-pages/vercel-2b-lloyds-pages`

## Quick Health Commands
```bash
# Prometheus
curl -fsS http://127.0.0.1:9090/-/healthy

# Alertmanager
curl -fsS http://127.0.0.1:9093/-/healthy

# Grafana
curl -fsS http://127.0.0.1:3000/api/health

# Active rules
curl -fsS http://127.0.0.1:9090/api/v1/rules | jq -r '.data.groups[]?.rules[]? | select(.type=="alerting") | [.name,.state,.health] | @tsv'

# Scrape targets
curl -fsS http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | [.labels.job,.labels.instance,.health,.lastError] | @tsv'

# Qdrant host-check metric
grep obs_qdrant_http_up /srv/stacks/observability/textfile/host_checks.prom
```

## Credentials and Secrets
- Runtime secrets are stored on host env files under:
  - `/srv/stacks/observability/.env`
  - `/srv/stacks/observability/scripts/alertmanager.env`
  - `/srv/stacks/observability/scripts/host_checks.env`
  - `/srv/stacks/observability/scripts/monthly_maintenance.env`
  - `/srv/stacks/observability/prometheus/secrets/qdrant_api_key`
- The schedule guard and monthly maintenance scripts also accept the Lloyds project aliases `ALERT_WEBHOOK_SLACK` and `ALERT_WEBHOOK_DISCORD` from `/Users/poovannanrajendran/Documents/GitHub/lloyds-market-news-digest/.env`.
- Recommended sync helper: `scripts/sync_runner_alert_env.sh` copies those aliases into the runner env files used by the guard and monthly maintenance jobs.
- Do not commit secret values to git.
- Seed `/srv/stacks/observability/.env` from `stacks/observability/.env.example`, replace every `CHANGE_ME` value, and set mode `0600` before deployment.
