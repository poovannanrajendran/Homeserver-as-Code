# Paperclip Role and Policy Bootstrap

This document defines the first production-safe role model for Paperclip in the homelab.

## Goals

- Keep Paperclip as the governance/control plane.
- Keep Hermes as the execution layer.
- Avoid OpenClaw wholesale migration.
- Start with a minimal, auditable role model.
- Use one grounded test task before expanding scope.

## Recommended First Roles

| Role | Purpose | Can Do | Cannot Do |
| --- | --- | --- | --- |
| `admin` | Full control of the Paperclip instance | Manage policies, roles, budgets, approvals, and all tasks | Nothing by default |
| `orchestrator` | Routes work to the right agent | Create and assign tasks, view status, read audit logs | Change security policy or approve destructive actions |
| `executor` | Performs approved work | Run allowed tools, return structured task results | Self-approve sensitive actions, change policy, widen permissions |
| `auditor` | Read-only oversight | Read runs, logs, and audit history | Create tasks, execute tools, modify policy |

## Policy Model

Start with these policies:

1. **Least privilege by default**
- Every role starts with the smallest useful tool set.
- No broad filesystem, network, or database access unless explicitly granted.

2. **Explicit task scopes**
- Every task must declare:
  - role
  - allowed tools
  - time limit
  - budget
  - success condition

3. **Approval thresholds**
- Sensitive actions require manual approval.
- Examples:
  - destructive shell commands
  - external-facing changes
  - credential or secret access
  - policy changes

4. **Audit required**
- Every role assignment, policy change, and task run must produce an audit event.

5. **No secret material in prompts**
- Keep tokens, passwords, and raw config out of tasks and docs.

## Initial Role Assignments

Recommended starting mapping:

- `Group CEO` -> `admin`
- `Paperclip Router` -> `orchestrator`
- `Hermes Worker` -> `executor`
- `Audit Viewer` -> `auditor`

## Initial Tool Allowlist

### `admin`
- all Paperclip control actions
- role and policy edits
- audit access

### `orchestrator`
- create tasks
- assign tasks to roles
- read task status
- read audit logs

### `executor`
- allowed runtime tools only
- no direct policy edits
- no secret reads unless explicitly scoped

### `auditor`
- read-only access to tasks, logs, and history

## Grounding Pack for Paperclip Background

Import the following background into Paperclip as a non-executable reference document:

- homelab topology
- current host roles
- Hermes installation state
- OpenClaw as legacy runtime
- preferred separation of governance vs execution
- no migration unless explicitly requested

Suggested content source:
- `docs/agentic-architecture-implementation.md`
- `tasks.md`
- `docs/index.md`

## First Test Task

Use one small end-to-end task:

- role: `executor`
- task: summarize current host status from a safe read-only source
- allowed tools: read-only shell or status endpoint only
- budget: tiny
- time limit: 2 minutes
- success: returns a structured summary and writes one audit record

## Exit Criteria

Paperclip bootstrap is ready for the next phase when:

- roles exist
- policies exist
- one audited task has run successfully
- the grounding pack is attached or imported as background
- Hermes orchestration remains deferred
