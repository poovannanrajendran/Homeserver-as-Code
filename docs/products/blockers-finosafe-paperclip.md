# Current Blockers & Issues: FinOSafe Paperclip Deployment

## 1. Primary Blocker: "User Does Not Have Access" Error
**Status:** Resolved on 2026-05-09
**Impact:** Fixed. The user (`poovannan@gmail.com`) now has an active owner membership on the active `FinOSafe Media Group` company (`FINAA`).

### Root Cause
1. **CLI Import Context:** The `FinOSafe Media Group` company was imported via the Paperclip CLI (`companies.sh add`) while the server was running in a bypassed `local_trusted` mode.
2. **Missing Membership Record:** Because the company was created by the "System" via the CLI, the logged-in web user (`poovannan@gmail.com`) was not automatically assigned as an "Owner" or "Board Member" in the underlying `company_memberships` database table.
3. **Authentication Failure:** When returning the server to `authenticated` mode, the user session is recognized, but the database query confirming authorization for the specific company ID fails.

### Resolution Applied
On 2026-05-09, direct embedded PostgreSQL access was restored by starting Paperclip cleanly and allowing it to remove the stale embedded Postgres lock file. The following live state was verified:

- Active company: `FinOSafe Media Group`, issue prefix `FINAA`, company ID `0584d231-b01f-4ed9-bebc-d70315d1c7e8`
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
The active company now has two user owners:

1. `local@paperclip.local`
2. `poovannan@gmail.com`

If the browser still shows a stale access error, sign out of Paperclip, clear the `paperclip-default.session_token` cookie for `192.168.1.30`, then sign back in with `poovannan@gmail.com`.

---

## 2. Resolved Issue: n8n MCP Node Unrecognized
**Status:** Resolved
**Description:** The initial n8n workflow imported by the user showed `?` for all MCP Server nodes.
**Resolution:** Identified that n8n updated their MCP node architecture. The workflow JSON was updated from the deprecated `n8n-nodes-base.mcpServer` to the new LangChain-compatible `@n8n/n8n-nodes-langchain.mcpTrigger`. The user successfully imported and published the corrected workflow.
