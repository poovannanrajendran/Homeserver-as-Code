# Agentic Architecture Implementation

## Purpose
This document captures the recommended implementation plan for integrating the actual Hermes Agent and Paperclip products into the homelab:

- **Hermes Agent** as the execution/runtime layer
- **Paperclip** as the governance/control-plane layer

The design is meant to fit the current homelab topology without overcommitting the existing AI host.

## Why This Split Exists

The current OpenClaw setup already does the hard part well:

- natural-language interaction
- agent routing
- channel handling
- memory and provider fallbacks

The missing piece is not more chat capability. It is a clearer separation between:

- **work execution**: scripts, data transforms, API calls, file parsing, database actions
- **control plane**: agent roles, budgets, policy, audit, and task delegation

That split keeps the system easier to reason about and safer to scale.

## Deployment Checklist

Use this as the execution order. Do not move to the next stage until the test gate passes.

1. Baseline capture
- confirm `ai-node-01` headroom
- confirm `automation-runner-01` headroom
- confirm existing OpenClaw state
- confirm current observability and backup coverage

2. Hermes bootstrap on `ai-node-01`
- install the Hermes Agent product
- verify the setup wizard and OpenClaw import path
- keep Hermes private to LAN / tailnet
- run one sample task end to end

3. Paperclip bootstrap on `automation-runner-01`
- install the Paperclip product
- keep it private to LAN / tailnet
- define the first roles and policy store
- verify the controller can register and audit a task

4. Routing integration
- connect OpenClaw to Hermes as the execution path
- connect Paperclip to Hermes as the governance path
- validate timeout, retry, and rejection handling

5. Memory and observability
- decide the memory namespaces
- add dashboards and alerts
- verify execution summaries after each run

6. Hardening and scale
- keep secrets local-only
- confirm least privilege
- split workloads only if the first deployment proves useful

## Current Implementation Status

Verified live on 2026-05-06:

- `ai-node-01`
  - Hermes Agent installed: `v0.12.0`
  - `hermes doctor` passes with non-blocking auth warnings
  - Hermes config and local skill sync completed
  - OpenClaw remains active on the host

- `automation-runner-01`
  - Node.js upgraded to `v24.15.0`
  - npm upgraded to `11.12.1`
  - Paperclip onboarding completed in LAN mode
  - `paperclipai doctor` passes with the expected port warning
  - Paperclip health endpoint returns `ok`
  - Paperclip bootstrap is complete and the instance is operational
  - Codex CLI is installed and authenticated for the runner user
  - Gemini CLI is installed and present in the global `PATH`

Current blockers:

- Hermes dashboard analytics still needs separate investigation if you want UI health parity with the CLI and Telegram gateway.
- Paperclip routing/orchestration with Hermes has not yet been wired.
- Paperclip requested port `3100`, but the runtime selected `3101` because `3100` was already busy.
- Paperclip access is gated by both network reachability and an app-level hostname allowlist; if `http://<host>:3101/api/health` returns `Hostname '<host>' is not allowed`, run `pnpm paperclipai allowed-hostname <host>` on the runner before re-testing.

## Recommended Placement

### Hermes Agent Execution Layer

Best host:
- `ai-node-01`

Why:
- already the dedicated AI host
- already runs OpenClaw
- already carries local model traffic via Ollama
- best place for code execution and model-adjacent workflows

Target size:
- `2-4 vCPU`
- `4-6 GB RAM`
- `20-40 GB disk`

Notes:
- keep it small at first
- do not assume GPU access
- prefer a container or lightweight VM
- do not move the whole orchestration stack here

Official product install path:
- Quick install: `curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash`
- First run: `hermes setup`
- OpenClaw migration: `hermes claw migrate`
- OpenClaw import on first setup is supported automatically when `~/.openclaw` is detected
- Recommended deployment mode on this homelab: run Hermes on `ai-node-01` and let the setup wizard import the existing OpenClaw profile, then keep the runtime private to the tailnet/LAN.

### Paperclip Governance Layer

Best host:
- `automation-runner-01`

Why:
- already acts as the control-plane host
- already runs scheduled jobs and observability
- already hosts Prometheus/Grafana/Alertmanager
- best place for policy, routing, task registry, and audit state

Target size:
- `1-2 vCPU`
- `2-4 GB RAM`
- `10-20 GB disk`

Notes:
- keep it stateless where possible
- persist policy and audit data to a small Postgres-backed store
- use it to coordinate agents, not to do heavy inference
- when validating reachability, check all three layers: container/service bind, host firewall (`ufw`), and Paperclip hostname allowlist (`paperclipai allowed-hostname`)

Official product install path:
- Quickstart: `npx paperclipai onboard --yes`
- One-command bootstrap: `pnpm paperclipai run`
- Local dev: `pnpm install && pnpm dev`
- Docker quickstart: `docker compose -f docker-compose.quickstart.yml up --build`
- Recommended deployment mode on this homelab: run Paperclip on `automation-runner-01` in private mode (`--bind tailnet` or `--bind lan`) so the control plane stays off the public internet.

Operational state:
- Paperclip is live on `automation-runner-01`
- LAN access is enabled with hostname allowlisting for `192.168.1.30`
- `codex` and `gemini` CLIs are installed on the runner and exposed via `/usr/local/bin`
- the first company dashboard is operational
- the initial roles and policies are being refined for the control plane

## Logical Responsibilities

### Hermes Responsibilities

Hermes should handle:

- code execution
- small Python workflows
- structured file parsing
- spreadsheet transforms
- database read/write workflows when explicitly permitted
- MCP tool use for direct system integration
- response generation from structured tool output

Hermes should not:

- own global permissions
- manage fleet-wide routing policy
- store long-term governance state
- become the primary orchestration layer

### Paperclip Responsibilities

Paperclip should handle:

- agent registration
- role mapping
- tool allow/deny policy
- budget and quota enforcement
- audit logs
- delegated task routing
- task assignment to specialized agents

Paperclip should not:

- become a second OpenClaw UI
- run large inference jobs
- duplicate execution logic
- own the model layer

## Suggested Host Map

| Host | Role | Notes |
| --- | --- | --- |
| `ai-node-01` | OpenClaw + Hermes Agent runtime | Primary AI runtime, local model access, agent tooling |
| `automation-runner-01` | Paperclip control plane | Scheduler, audit, policy, dashboards |
| `docker-host-01` | Shared service host | Databases, Authentik, Outline, support services |

## Integration Boundaries

### Hermes to OpenClaw

Hermes should be invoked as the execution runtime behind OpenClaw, not as a replacement for it.

Recommended interfaces:

- OpenClaw agent turns
- MCP tools
- terminal or sandbox execution
- explicit task APIs

### Paperclip to OpenClaw

Paperclip should sit above the agent runtime:

- it decides which agent gets the task
- it decides which tools that agent may use
- it tracks who did what

Paperclip should not own the conversational channel itself.

### Paperclip to Hermes

Paperclip may dispatch jobs to Hermes with:

- a task type
- a role
- a budget
- a tool scope
- an expiry / timeout

Hermes then executes within those constraints and returns structured results.

## Paperclip Operations Summary

Paperclip is now operating as the control plane for the homelab. The next work is governance refinement, not installation:

- role tuning
- policy tightening
- background grounding import
- one audited read-only test task
- later Hermes orchestration

## Recommended Data Stores

### Hermes

Use only the minimum required persistent state:

- conversation/session notes
- execution artifacts
- temporary working files
- local memory or embeddings if needed

### Paperclip

Use durable control-plane storage:

- agent registry
- role assignments
- policy rules
- budgets
- execution audit events
- delegation history

Recommended store:
- Postgres

Optional additions:
- Redis for short-lived coordination
- object storage for logs or artifacts if volume grows

## Security Model

### Execution Layer

Hermes should operate with:

- least privilege
- explicit tool allowlists
- sandboxed execution where possible
- no broad database access by default

### Governance Layer

Paperclip should enforce:

- role-based permissions
- approval thresholds for sensitive actions
- model and tool budgets
- audit retention

### Secrets

Keep secrets out of:

- agent prompts
- public docs
- task files committed to GitHub

Store secrets in the existing local secret workflow only.

## Rollout Phases

### Phase 1: Product bootstrap

Goal:
- install the official Hermes Agent and Paperclip products in the chosen hosts with conservative defaults

Deliverables:

- Hermes Agent installed on `ai-node-01`
- Hermes gateway and/or CLI available
- Hermes migration from OpenClaw evaluated and, if safe, applied
- Paperclip installed on `automation-runner-01`
- Paperclip UI reachable on the private network
- initial audit log
- initial task dispatch contract

### Suggested bootstrap commands

Hermes:
```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
hermes setup
hermes claw migrate
```

Paperclip:
```bash
npx paperclipai onboard --yes --bind tailnet
# or, for LAN-only access:
npx paperclipai onboard --yes --bind lan
```

### Stage Test Gates

Each stage must pass before you proceed:

- Baseline test: resource headroom is within safe bounds
- Hermes test: setup completes and one task returns structured output
- Paperclip test: controller starts and records one audited action
- Routing test: OpenClaw can dispatch a task and receive a result
- Memory test: the chosen namespace strategy survives a restart
- Observability test: the health dashboard and alerts show the new components

### Phase 2: Policy

Goal:
- make tool access explicit and defensible

Deliverables:

- role definitions
- tool allowlists
- approval gates
- budget enforcement

### Phase 3: Observability

Goal:
- make the system inspectable and supportable

Deliverables:

- dashboards
- alerts
- execution summaries
- failure tracking

### Phase 4: Scaling

Goal:
- split components only when load justifies it

Deliverables:

- separate execution workers by workload
- optional extra VM for heavy jobs
- workload-specific queues

## Acceptance Criteria

The implementation is acceptable when:

- Hermes Agent runs on `ai-node-01` and can accept tasks safely
- Paperclip runs on the control-plane host and can govern roles and budgets
- Hermes can migrate from OpenClaw without breaking the existing workflow
- agent actions are auditable
- the AI node remains within safe CPU and memory bounds
- the runner can survive a reboot and resume governance duties
- no sensitive values are committed to the public repo

## Recommended Next Step

Implement the smallest possible proof of concept:

- one execution worker on `ai-node-01`
- one governance controller on `automation-runner-01`
- one durable audit table
- one explicit role mapping

Keep it narrow until the operational value is proven.
