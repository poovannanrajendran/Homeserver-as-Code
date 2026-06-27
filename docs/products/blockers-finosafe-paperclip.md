# Current Blockers & Issues: FinOSafe Paperclip Deployment

## Current Status

**Status:** No active deployment blockers as of 2026-05-11.

FinOSafe Paperclip is healthy on `automation-runner-01`, accessible at `http://192.168.1.30:3101`, and validated end-to-end through the `alpha-researcher` agent runtime and the n8n MCP workflow `Paperclip MCP Tools (FinOSafe)`.

The only remaining active work items are product/content backlog issues:

- `FINAA-1`: `daily-news-short`
- `FINAA-2`: `niche-topic-deep-dive`

Validation and recovery artifacts are closed:

- `FINAA-3`: cancelled
- `FINAA-4`: cancelled
- `FINAA-5`: done
- `FINAA-6`: done
- `FINAA-7`: done
- `FINAA-8`: done
- `FINAA-9`: done

## 1. Primary Blocker: "User Does Not Have Access" Error
**Status:** Resolved on 2026-05-09
**Impact:** Fixed. The user (`poovannan@gmail.com`) now has an active owner membership on the active `FinOSafe Media Group` company (`FINAA`).

### Root Cause
1. **CLI Import Context:** The `FinOSafe Media Group` company was imported via the Paperclip CLI (`companies.sh add`) while the server was running in a bypassed `local_trusted` mode.
2. **Missing Membership Record:** Because the company was created by the "System" via the CLI, the logged-in web user (`poovannan@gmail.com`) was not automatically assigned as an "Owner" or "Board Member" in the underlying `company_memberships` database table.
3. **Authentication Failure:** When returning the server to `authenticated` mode, the user session is recognized, but the database query confirming authorization for the specific company ID fails.

### Resolution Applied
On 2026-05-09, direct embedded PostgreSQL access was restored by starting Paperclip cleanly and allowing it to remove the stale embedded Postgres lock file. The following live state was verified:

- Historical pre-reimport company: `FinOSafe Media Group`, issue prefix `FINAA`, company ID `0584d231-b01f-4ed9-bebc-d70315d1c7e8`
- User: `poovannan@gmail.com`, user ID `BYFL4Lvz3FDO54i9PDycOZ7QTtFUEHK3`
- Inserted active owner membership into `company_memberships`
- Runtime changed back to documented web mode: `server.deploymentMode=authenticated`, `server.bind=lan`, `server.host=0.0.0.0`, `server.port=3101`
- Auth base URL set explicitly to `http://192.168.1.30:3101` to avoid callback/redirect ambiguity
- Paperclip restarted and confirmed listening on `0.0.0.0:3101`

Pre-fix DB snapshot:

- `/home/labadmin/.paperclip/instances/default/data/backups/finosafe-access-pre-fix-20260509-105523.txt`

### Attempted Remediations
1. **Bootstrap CEO Invite:** Generated multiple `bootstrap-ceo` invite links using `npx paperclipai auth bootstrap-ceo --force`.
   - *Result:* Clicking the link in an Incognito window failed to map the existing user to the new company, resulting in a black screen or persistent access error.
2. **Manual Database Injection:** Attempted to use `psql` to directly insert a `company_member` record linking the user's UUID to the company's UUID.
   - *Result:* Failed due to authentication/connectivity issues with the embedded PostgreSQL instance on port 54329 (`FATAL: password authentication failed for user "paperclip"` and `Connection refused`).
3. **Re-import under Auth:** Attempted to list and delete companies via the CLI to start fresh, but CLI access requires `local_trusted` mode or a valid API key, leading to a circular dependency of permissions.

### Validation
The active company was later re-imported and validated as:

- Company: `FinOSafe Media Group`
- Prefix: `FINAA`
- Active company ID: `2dae29b7-aa61-48e5-8ead-35c540c9f3a6`
- Owner/admin: `poovannan@gmail.com`

The active company now has owner/admin access for:

1. `local@paperclip.local`
2. `poovannan@gmail.com`

If the browser still shows a stale access error, sign out of Paperclip, clear the `paperclip-default.session_token` cookie for `192.168.1.30`, then sign back in with `poovannan@gmail.com`.

---

## 2. Resolved Issue: n8n MCP Node Unrecognized
**Status:** Resolved
**Description:** The initial n8n workflow imported by the user showed `?` for all MCP Server nodes.
**Resolution:** Identified that n8n updated their MCP node architecture. The workflow JSON was updated from the deprecated `n8n-nodes-base.mcpServer` to the new LangChain-compatible `@n8n/n8n-nodes-langchain.mcpTrigger`. The user successfully imported and published the corrected workflow.

---

## 3. Resolved Issue: Wrong n8n MCP Endpoint Path

**Status:** Resolved on 2026-05-10

### Symptom

Paperclip/Codex could not complete n8n MCP initialization through the previously assumed `/mcp-server/...` endpoint.

### Root Cause

n8n exposes MCP trigger SSE endpoints under `/mcp/<trigger-id>/sse`. The `/mcp-server/<trigger-id>/sse` path returns n8n UI HTML and is not a valid MCP SSE transport for these workflow triggers.

### Resolution Applied

Configured the FinOSafe proxy to call the correct trigger endpoints:

- `web_search`: `/mcp/2f8583d0-141d-487a-8adb-f062bd14301f/sse`
- `financial_data_api`: `/mcp/276cc567-a9f3-4197-b1e0-e10b1d5e4989/sse`
- `qdrant_search`: `/mcp/7acf451c-4642-4fab-976d-af0d44d5d6ec/sse`
- `youtube_api`: `/mcp/9870d8f5-d0a3-4616-b075-b57c36d091c2/sse`
- `reddit_social_search`: `/mcp/7e9c3bd3-aa4c-4796-ad0c-b3f9aeddc2cf/sse`

### Validation

Direct proxy and agent-backed calls succeeded. n8n executions `131` through `135` were recorded as `success`.

---

## 4. Resolved Issue: n8n Tool Input Mapping

**Status:** Resolved on 2026-05-10

### Symptom

The Tavily node returned missing-field errors because the HTTP request node expected `$json.query`, but MCP tool calls were not producing that input shape.

### Root Cause

The active n8n workflow used plain `$json.*` expressions instead of n8n AI tool argument expressions.

### Resolution Applied

Updated the active n8n workflow to use `$fromAI(...)` expressions and clear tool names:

- `web_search` query uses `$fromAI('query', 'The web search query', 'string')`
- `financial_data_api` symbol uses `$fromAI('symbol', 'Ticker symbol, for example AAPL or MSFT', 'string')`
- YouTube and Reddit search tools use equivalent `$fromAI('query', ...)` mappings

### Validation

`web_search` returned `Insurance News | InsuranceNewsNet`. `financial_data_api` returned AAPL price `293.3200`.

---

## 5. Resolved Issue: Agent Runtime Sandbox and Trust Failures

**Status:** Resolved on 2026-05-11

### Symptoms

Earlier Codex agent runs failed with runtime errors such as:

- `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`
- `Not inside a trusted directory and --skip-git-repo-check was not specified`

### Root Cause

The automation runner cannot use the default sandbox path for this Paperclip/Codex runtime, and initial runs lacked a usable execution workspace/project mapping.

### Resolution Applied

- Enabled bypass of Codex approvals/sandbox for the FinOSafe Codex-backed agents.
- Enabled search for Codex-backed agents.
- Created and attached the `content-flywheel` Paperclip project/workspace.
- Ensured live runtime uses the `finosafe-live` instance path.
- Added a local stdio MCP proxy at `/home/labadmin/bin/finosafe-n8n-mcp.py`.

### Validation

`FINAA-9` was completed by `alpha-researcher` through a live Codex heartbeat run:

- Run ID: `f9c8f845-c07d-489b-af35-f0f2eecd6f6e`
- Status: `succeeded`
- n8n workflow executions: `131` through `135`, all `success`

---

## 6. Important Recovery Paths

| Purpose | Path |
| --- | --- |
| FinOSafe working directory | `/home/labadmin/paperclip-company-finosafe` |
| Paperclip service override | `/home/labadmin/.config/systemd/user/paperclip.service.d/override.conf` |
| Live Paperclip instance | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live` |
| Live MCP config | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live/mcp.json` |
| Codex home for FinOSafe agents | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live/companies/2dae29b7-aa61-48e5-8ead-35c540c9f3a6/codex-home` |
| n8n MCP proxy | `/home/labadmin/bin/finosafe-n8n-mcp.py` |
| n8n database | `/opt/automation/n8n/data/database.sqlite` |

For the full recovery log, see `docs/runbooks/paperclip-finosafe-recovery-validation.md`.
