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
- Live FinOSafe instance: `finosafe-live`
- Live FinOSafe company: `FinOSafe Media Group` / `FINAA`
- Live FinOSafe company ID: `2dae29b7-aa61-48e5-8ead-35c540c9f3a6`
- Authenticated CLI tools available on the host:
  - `codex`
  - `gemini`

## Live Paths

| Purpose | Path |
| --- | --- |
| FinOSafe working directory | `/home/labadmin/paperclip-company-finosafe` |
| Paperclip service | `/home/labadmin/.config/systemd/user/paperclip.service` |
| Paperclip service override | `/home/labadmin/.config/systemd/user/paperclip.service.d/override.conf` |
| FinOSafe instance data | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live` |
| FinOSafe MCP config | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live/mcp.json` |
| FinOSafe Codex home | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live/companies/2dae29b7-aa61-48e5-8ead-35c540c9f3a6/codex-home` |
| FinOSafe n8n MCP proxy | `/home/labadmin/bin/finosafe-n8n-mcp.py` |
| n8n database | `/opt/automation/n8n/data/database.sqlite` |

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

## Local Mac Model Guidance

The local Paperclip company on the Mac should not be configured as a single generic wrapper.

Current wrapper config in `paperclip/poovi_papercompany/.paperclip.yaml` uses:

- `chief-of-staff` -> `claude_local`
- `researcher` -> `codex_local`
- `lab-engineer` -> `codex_local`
- `content-strategist` -> `claude_local`
- `career-strategist` -> `claude_local`
- `growth-operator` -> `codex_local`
- `finance-analyst` -> `codex_local`
- `archivist` -> `codex_local`

Recommended provider/model split:

| Agent | Provider | Model |
| --- | --- | --- |
| `chief-of-staff` | Claude | `claude-3-5-haiku-20241022` |
| `researcher` | Gemini or Ollama | `gemini-2.5-flash` or `qwen2.5:14b` |
| `lab-engineer` | Codex | `gpt-5.4` or `gpt-5.4-mini` |
| `content-strategist` | Claude | `claude-3-5-haiku-20241022` or `claude-sonnet-4-6` |
| `career-strategist` | Claude | `claude-sonnet-4-6` |
| `growth-operator` | Gemini | `gemini-2.5-flash` |
| `finance-analyst` | Ollama | `qwen2.5:14b` or `deepseek-r1:14b` |
| `archivist` | Ollama | `llama3.2:latest` or `phi4-mini` |

Why this split:

- Claude is the best fit for orchestration and writing.
- Gemini is the best fit for fast synthesis and ideation.
- Codex is the best fit for code and tool-heavy work.
- Ollama is the best fit for local, private, repeatable tasks.
- `qwen3.5:27b` is too heavy for always-on use on a 24 GB unified-memory Mac.

See:

- [Paperclip Local Company Handbook](runbooks/paperclip-local-company-handbook.md)
- [Paperclip Local Company Usage Guide](runbooks/paperclip-local-company-usage-guide.md)

## n8n MCP Tool Integration

Paperclip's research and data agents are exposed via an n8n MCP Server workflow.

- Workflow name: `Paperclip MCP Tools (FinOSafe)`
- Workflow ID: `OJVWHJzekaQPzihW`
- Source file: `n8n/Paperclip MCP Tools (FinOSafe).json`
- n8n instance: `http://192.168.1.30:5678`
- MCP exposure: `availableInMCP: true` (set in workflow settings)
- Transport used by Paperclip agents: local stdio proxy at `/home/labadmin/bin/finosafe-n8n-mcp.py`
- Correct n8n MCP trigger URL pattern: `/mcp/<trigger-id>/sse`
- Incorrect route to avoid: `/mcp-server/<trigger-id>/sse`

### Tool Chains

| MCP Tool | Downstream Node | Endpoint | Status |
| --- | --- | --- | --- |
| `web_search` | Tavily | `https://api.tavily.com/search` | Validated |
| `financial_data_api` | Alpha Vantage | `https://www.alphavantage.co/query` | Validated |
| `qdrant_search` | Qdrant | `http://192.168.1.20:6333` | Configured |
| `youtube_api` | YouTube | `https://www.googleapis.com/youtube/v3/search` | Configured |
| `reddit_social_search` | Reddit | `https://www.reddit.com/search.json` | Configured |

### Validation Record

- 2026-05-11: `FINAA-9` completed through `alpha-researcher`.
- Codex heartbeat run: `f9c8f845-c07d-489b-af35-f0f2eecd6f6e`, status `succeeded`.
- n8n workflow executions: `131` through `135`, status `success`.
- `web_search` returned `Insurance News | InsuranceNewsNet`.
- `financial_data_api` returned AAPL price `293.3200`, latest trading day `2026-05-08`.

### Activation Checklist

- [x] Fill in required API keys in n8n action nodes
- [x] Connect each MCP Trigger to its downstream action node
- [x] Toggle workflow to **Active** in n8n
- [x] Confirm n8n MCP trigger endpoints use `/mcp/<trigger-id>/sse`
- [x] Register the local n8n MCP proxy in Paperclip/Codex tool config

### Connection Note

The MCP Trigger's **right-side** output (`main`) connects to the HTTP Request node. The **bottom "Tools"** port is for LangChain Tool wrapper nodes — do not use it for HTTP Request chains.

## Related Docs

- [Paperclip Local Company Handbook](runbooks/paperclip-local-company-handbook.md)
- [Paperclip Local Company Usage Guide](runbooks/paperclip-local-company-usage-guide.md)
- [FinOSafe Recovery and Validation Runbook](runbooks/paperclip-finosafe-recovery-validation.md)
- `docs/agentic-architecture-implementation.md`
- `docs/paperclip-role-policy-bootstrap.md`
- `tasks.md`
