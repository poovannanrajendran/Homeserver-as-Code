# FinOSafe Paperclip Recovery and Validation Runbook

This runbook records the 2026-05-10/11 recovery of the FinOSafe Paperclip company on `automation-runner-01`.

## Scope

This document applies only to the remote FinOSafe Paperclip company:

- Host: `automation-runner-01`
- LAN IP: `192.168.1.30`
- Paperclip URL: `http://192.168.1.30:3101`
- n8n URL: `http://192.168.1.30:5678`
- Company: `FinOSafe Media Group`
- Issue prefix: `FINAA`
- Company ID: `2dae29b7-aa61-48e5-8ead-35c540c9f3a6`

Do not use this runbook for the local Paperclip lab company.

## Final Validated State

- Paperclip health is `ok`.
- Paperclip deployment mode is `authenticated`.
- Bootstrap is complete and invite is inactive.
- `poovannan@gmail.com` is an instance admin and company owner/member.
- Paperclip is listening on `0.0.0.0:3101`.
- n8n is listening on `0.0.0.0:5678`.
- Embedded Postgres is listening on `127.0.0.1:5544`.
- `alpha-researcher` successfully completed `FINAA-9`.
- n8n workflow `Paperclip MCP Tools (FinOSafe)` recorded successful executions.

## Important Paths

| Purpose | Path |
| --- | --- |
| FinOSafe working directory | `/home/labadmin/paperclip-company-finosafe` |
| Paperclip service | `/home/labadmin/.config/systemd/user/paperclip.service` |
| Paperclip service override | `/home/labadmin/.config/systemd/user/paperclip.service.d/override.conf` |
| Live Paperclip instance | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live` |
| Live Paperclip MCP config | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live/mcp.json` |
| FinOSafe Codex home | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live/companies/2dae29b7-aa61-48e5-8ead-35c540c9f3a6/codex-home` |
| n8n MCP stdio proxy | `/home/labadmin/bin/finosafe-n8n-mcp.py` |
| n8n SQLite database | `/opt/automation/n8n/data/database.sqlite` |
| Local repo mirror | `paperclip/finosafe/` |

## Issues Found and Fixes Applied

### 1. Browser Access and Login Drift

**Symptom:** Paperclip login and company access were inconsistent after switching between ports and bootstrap states.

**Root Cause:** The live deployment needed to remain on `3101`; temporary `3111` testing created browser confusion. The authenticated instance also needed the user/admin membership confirmed.

**Fix:**

- Kept Paperclip on `3101`.
- Allowed LAN access to `3101`.
- Confirmed `poovannan@gmail.com` as an instance admin and active company owner/member.
- Confirmed the browser shows the `FINOSAFE-LIVE` instance.

### 2. Wrong n8n MCP Endpoint

**Symptom:** MCP initialization failed or received HTML instead of a JSON-RPC/SSE stream.

**Root Cause:** The assumed `/mcp-server/<trigger-id>/sse` route is not the correct endpoint for the active n8n MCP triggers.

**Fix:**

- Used `/mcp/<trigger-id>/sse`.
- Added `/home/labadmin/bin/finosafe-n8n-mcp.py` as a local stdio proxy for Paperclip/Codex.

### 3. n8n Tool Input Shape

**Symptom:** Tavily returned missing-field errors for tool calls.

**Root Cause:** The workflow used `$json.query` and `$json.symbol` in HTTP Request nodes, but MCP tool calls need AI tool argument expressions.

**Fix:**

- Updated the active n8n workflow to use `$fromAI(...)`.
- Renamed connected action nodes to stable tool-facing names:
  - `web_search`
  - `financial_data_api`
  - `qdrant_search`
  - `youtube_api`
  - `reddit_social_search`

### 4. Codex Sandbox Failure

**Symptom:** Agent runs failed with `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`.

**Root Cause:** The automation runner environment cannot use the default Codex sandbox path for this Paperclip runtime.

**Fix:**

- Enabled `dangerouslyBypassApprovalsAndSandbox` for Codex-backed FinOSafe agents.
- Kept the environment private to LAN and under Paperclip-controlled task execution.

### 5. Codex Trusted Directory Failure

**Symptom:** Agent runs failed with `Not inside a trusted directory and --skip-git-repo-check was not specified`.

**Root Cause:** Paperclip initially had no reliable project/workspace mapping for the issue runtime, so runs fell back to agent home workspaces.

**Fix:**

- Created/attached the `content-flywheel` project and project workspace.
- Confirmed subsequent runs can execute through the Paperclip runtime.

### 6. Validation Recovery Loops

**Symptom:** `FINAA-6`, `FINAA-7`, and `FINAA-8` recovery artifacts remained blocked or visible.

**Root Cause:** Earlier automatic retries hit Codex quota and recovery logic created follow-up issues.

**Fix:**

- Validated the same workflow manually and then through a live agent issue.
- Closed recovery artifacts after confirming there was no remaining Paperclip/n8n configuration error.

## Validated Agent and Model Configuration

| Agent | Adapter | Model | Reports To |
| --- | --- | --- | --- |
| `strategist` | `codex_local` | `gpt-5.4-mini` | |
| `alpha-researcher` | `codex_local` | `gpt-5.4-mini` | `strategist` |
| `growth-hacker` | `codex_local` | `gpt-5.4-mini` | `strategist` |
| `market-sentry` | `codex_local` | `gpt-5.4-mini` | `strategist` |
| `viral-writer` | `claude_local` | `claude-haiku-4-5-20251001` | `strategist` |

## Validated n8n MCP Tools

| Tool | Trigger ID | Validation |
| --- | --- | --- |
| `web_search` | `2f8583d0-141d-487a-8adb-f062bd14301f` | Returned `Insurance News | InsuranceNewsNet` |
| `financial_data_api` | `276cc567-a9f3-4197-b1e0-e10b1d5e4989` | Returned AAPL price `293.3200` |
| `qdrant_search` | `7acf451c-4642-4fab-976d-af0d44d5d6ec` | Configured |
| `youtube_api` | `9870d8f5-d0a3-4616-b075-b57c36d091c2` | Configured |
| `reddit_social_search` | `7e9c3bd3-aa4c-4796-ad0c-b3f9aeddc2cf` | Configured |

## Validation Evidence

### Paperclip Health

```bash
ssh labadmin@automation-runner-01 \
  'curl -fsS http://127.0.0.1:3101/api/health'
```

Expected result:

```json
{"status":"ok","deploymentMode":"authenticated","bootstrapStatus":"ready","bootstrapInviteActive":false}
```

### n8n Execution Check

```bash
cat <<'PY' | ssh labadmin@automation-runner-01 'python3 -'
import sqlite3
con = sqlite3.connect('/opt/automation/n8n/data/database.sqlite')
for row in con.execute("""
    select id, mode, status, startedAt, stoppedAt
    from execution_entity
    where workflowId='OJVWHJzekaQPzihW'
    order by cast(id as integer) desc
    limit 8
"""):
    print(row)
PY
```

Validated successful execution IDs included `131`, `132`, `133`, `134`, and `135`.

### Agent Runtime Check

```bash
ssh labadmin@automation-runner-01 \
  "PGPASSWORD=\${PAPERCLIP_DB_PASSWORD:?set PAPERCLIP_DB_PASSWORD} psql -h 127.0.0.1 -p 5544 -U paperclip -d paperclip -F ' | ' -Atc \
  \"select id,status,agent_id,started_at,finished_at,error_code
    from heartbeat_runs
    where company_id='2dae29b7-aa61-48e5-8ead-35c540c9f3a6'
    order by started_at desc
    limit 5;\""
```

Validated run:

- Run ID: `f9c8f845-c07d-489b-af35-f0f2eecd6f6e`
- Agent: `alpha-researcher`
- Status: `succeeded`

## Issue Board State After Recovery

| Issue | Status | Meaning |
| --- | --- | --- |
| `FINAA-1` | `backlog` | Production `daily-news-short` task |
| `FINAA-2` | `backlog` | Production `niche-topic-deep-dive` task |
| `FINAA-3` | `cancelled` | Superseded n8n validation issue |
| `FINAA-4` | `cancelled` | Superseded recovery artifact |
| `FINAA-5` | `done` | Clean n8n validation |
| `FINAA-6` | `done` | Final validation, closed after manual confirmation |
| `FINAA-7` | `done` | Recovery artifact |
| `FINAA-8` | `done` | Recovery artifact |
| `FINAA-9` | `done` | Agent runtime smoke test |

## Next Step

Assign the first real content task from `FINAA-1` to `alpha-researcher` and monitor:

- Paperclip run logs in the agent `Runs` tab.
- n8n executions for workflow `OJVWHJzekaQPzihW`.
- Any issue comments generated by `alpha-researcher`, `viral-writer`, or `growth-hacker`.
