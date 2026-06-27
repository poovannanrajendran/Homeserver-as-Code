# Outline (Family Wiki) - Self Hosted

This runbook deploys Outline with Authentik (OIDC) for family logins.

No external providers (Google/Gmail) are required: create local username/password users in Authentik.

Design goals:
- Simple page creation UI (images, text, code blocks)
- Private access via Tailscale (no public port forwarding)
- Account control via an IdP (Authentik) rather than open signup

## 1) Deploy Authentik

1. Create env:
   ```bash
   cp examples/env/authentik.env.example stacks/authentik/.env
   ```
2. Set:
   - `AUTHENTIK_SECRET_KEY`
   - `AUTHENTIK_POSTGRESQL__PASSWORD`
   - Replace every remaining `CHANGE_ME` placeholder and set `.env` mode to `0600`
3. Start:
   ```bash
   cd stacks/authentik && docker compose up -d
   ```
4. Open Authentik UI (LAN or Tailscale):
   - `http://<docker-host-lan-ip-or-dns>:9000`
   - `http://docker-host-01.<tailnet>.ts.net:9000`

Note:
- `9443` is often already used by Portainer. This stack defaults Authentik HTTPS to `9444` to avoid collisions.

## 2) Configure Authentik for Outline (OIDC)

In Authentik:
1. Create a Group for your family members (example: `family`).
2. Create local Users (username + password) for each family member and add them to the group.
   - Outline expects an email claim. You can use a private domain like `poovannan@family.local` if you don't want real emails.
3. Create an OIDC Provider.
4. Create an Application that uses that provider.

Set the redirect URI on the provider/app:
- `http://<outline-host>:3010/auth/oidc.callback`

Where `<outline-host>` is either your LAN DNS/IP or your Tailscale name:
- `docker-host-01.<tailnet>.ts.net`

Record:
- Client ID
- Client Secret
- Issuer endpoints (authorize/token/userinfo)

## 3) Deploy Outline

1. Create env:
   ```bash
   cp examples/env/outline.env.example stacks/outline/.env
   ```
2. Set:
   - `OUTLINE_BIND_IP=0.0.0.0` for LAN + Tailscale access
   - `URL` to your intended external URL (LAN or Tailscale)
   - `SECRET_KEY` and `UTILS_SECRET`
   - `POSTGRES_PASSWORD` and ensure `DATABASE_URL` matches it
   - `OIDC_*` values from Authentik
   - Replace every remaining `CHANGE_ME` or angle-bracket placeholder and set `.env` mode to `0600`
3. Start:
   ```bash
   cd stacks/outline && docker compose up -d
   ```
4. Open Outline over Tailscale:
   - `http://<docker-host-lan-ip-or-dns>:3010`
   - `http://docker-host-01.<tailnet>.ts.net:3010`

## 4) Family Collections + Permissions

Outline does not reliably support "pre-seeding" collections via config; do it once in the UI.

Recommended pattern:
- Collections:
  - `Common`
  - `Poovannan`
  - `Bama`
  - `Aradhana (School)`
  - `Arjun (School)`
- Groups:
  - `Adults` (full access to all collections)
  - `Aradhana` (access to `Common` + `Aradhana (School)`)
  - `Arjun` (access to `Common` + `Arjun (School)`)

## 5) Outline API Key + MCP

Outline supports API keys (Settings -> API).

If you want MCP access, a community MCP server exists for Outline. Typical setup:
- Set `OUTLINE_API_URL` to `http://<outline-host>:3010/api`
- Set `OUTLINE_API_KEY` to the token you created in Outline

## Notes On Logout
OIDC logout URLs vary by IdP and configuration. If you hit issues with `OIDC_LOGOUT_URI`, leave it unset initially and rely on Outline session expiry, or configure an Authentik logout flow once you confirm the URL you want.

## Operational Notes
- Backups: include `/srv/data/outline/postgres`, `/srv/data/outline/redis`, `/srv/data/outline/storage`.
- Keep Outline and Authentik private to your tailnet; do not expose to the public internet unless you intend to harden it.
- `scripts/deploy_outline_authentik_remote.sh` uploads only templates and refuses to start either stack while placeholders remain in runtime `.env` files.
