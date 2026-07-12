# Local Paperclip Removal Record

## Summary

The accidental local Paperclip installation on the MacBook Pro was removed on 2026-05-09. This was a local-only cleanup and did not affect the production Paperclip instance on `automation-runner-01` or the FinOSafe company source files in this repository.

Related runbook:

- [Runbook: Safely Uninstall Local Paperclip (MacBook)](uninstall-local-paperclip.md)

## Scope

Removed local MacBook state and cache for:

- Paperclip local instance state: `~/.paperclip`
- Paperclip NPX cache entries under `~/.npm/_npx`
- Cached `paperclipai`
- Cached `companies.sh`
- Cached `@paperclipai`
- Cached `@embedded-postgres`

Preserved:

- `paperclip/finosafe/`
- Remote Paperclip on `automation-runner-01`
- FinoSafe Paperclip dashboard at `http://192.168.1.30:3101`

## Pre-Removal State

Before removal:

- No local Paperclip processes were running.
- No local listeners existed on ports `3100`, `3101`, or `54329`.
- Local state directory existed at `~/.paperclip`.
- Local Paperclip config was a loopback development instance:
  - `deploymentMode=local_trusted`
  - `bind=loopback`
  - `host=127.0.0.1`
  - `port=3100`
  - embedded Postgres port `54329`
- Local `mcp.json` contained an n8n bearer-token bridge to `192.168.1.30`, so removal also reduced local secret sprawl.
- Local footprint was approximately:
  - `~/.paperclip`: `71M`
  - `~/.npm/_npx`: `1.2G`

## Commands Executed

The cleanup used targeted removal rather than wiping the whole NPX cache:

```bash
rm -rf ~/.paperclip

find ~/.npm/_npx -maxdepth 4 \
  \( -path '*/node_modules/paperclipai' \
     -o -path '*/node_modules/@paperclipai' \
     -o -path '*/node_modules/@embedded-postgres' \
     -o -path '*/node_modules/companies.sh' \) \
  -prune -exec rm -rf {} + 2>/dev/null || true

find ~/.npm/_npx -maxdepth 2 -type d -empty -delete 2>/dev/null || true
```

No `pkill` was required because there were no live Paperclip processes.

## Post-Removal Validation

Validation checks passed:

```text
~/.paperclip removed
No Paperclip/companies.sh cached packages found under ~/.npm/_npx
No Paperclip processes running
No listeners on 3100, 3101, or 54329
```

NPX cache reduced from `1.2G` to `740M`.

## Operational Decision

Paperclip should now be operated from the remote runner only:

- Host: `automation-runner-01`
- URL: `http://192.168.1.30:3101`
- Service: `paperclip.service` under the `labadmin` user systemd instance

Avoid running `npx paperclipai run` on the MacBook unless intentionally creating a new local sandbox.
