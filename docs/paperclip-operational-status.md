# Paperclip Operational Status

Paperclip is now operating as the governance/control plane on `automation-runner-01`.

## Live State

- Host: `automation-runner-01`
- Bind: private LAN mode
- Port: `3101`
- Health: `ok`
- Bootstrap: complete
- Hostname allowlist: configured for `192.168.1.30`
- Storage: embedded Postgres + local disk
- Authenticated CLI tools available on the host:
  - `codex`
  - `gemini`

## Current Responsibilities

Paperclip is currently used for:

- company and agent dashboard operations
- role and policy management
- audited task execution
- control-plane decisions
- future Hermes orchestration

## Current Policy Model

The first role model is documented in:

- `docs/paperclip-role-policy-bootstrap.md`

Current roles:

- `admin`
- `orchestrator`
- `executor`
- `auditor`

## Operational Notes

- Hermes orchestration is intentionally deferred.
- OpenClaw remains the legacy runtime and conversational system.
- Paperclip is the governance layer above the runtime.
- The setup should stay private to LAN or tailnet.

## Related Docs

- `docs/agentic-architecture-implementation.md`
- `docs/paperclip-role-policy-bootstrap.md`
- `tasks.md`
