# Security Policy

## Reporting
If you find a security issue, open a private security advisory or contact the repository owner directly.

## Public Repository Rules
- Never commit real credentials.
- Never commit private hostnames, internal DNS zones, or real LAN IP plans.
- Never commit production backup archives.

## Secrets Handling
- Keep secrets in private `.env` files ignored by Git.
- Use `.env.example` templates with `CHANGE_ME` placeholders.
- Rotate credentials after initial bootstrap and after any accidental exposure.
- Keep workflow exports containing embedded provider keys out of Git; commit only sanitised canonical exports.
- Keep generated credentials, OAuth state, private keys, database dumps, browser captures, and runtime output ignored.
- Run a staged-content secret scan before every push.

## Required Runtime Secret Files
- Observability Compose: `/srv/stacks/observability/.env` (Grafana admin password and PostgreSQL exporter DSN)
- Observability health checks: `/srv/stacks/observability/scripts/host_checks.env`
- Alertmanager rendering: `/srv/stacks/observability/scripts/alertmanager.env`
- Outline and Authentik: `/srv/stacks/outline/.env` and `/srv/stacks/authentik/.env`
- Paperclip local lab: `stacks/paperclip-lab/.env`

Set runtime secret files to mode `0600`. Only `.env.example` templates belong in Git.
