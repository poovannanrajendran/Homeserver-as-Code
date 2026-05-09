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
- Source file: `n8n/Paperclip MCP Tools (FinOSafe).json`
- n8n instance: `http://192.168.1.30:5678`
- MCP exposure: `availableInMCP: true` (set in workflow settings)

### Tool Chains

| MCP Tool | Downstream Node | Endpoint | Status |
| --- | --- | --- | --- |
| `web_search` | HTTP Request (Tavily) | `https://api.tavily.com/search` | API key present — needs activation |
| `financial_data` | HTTP Request (Alpha Vantage) | `https://www.alphavantage.co/query` | Replace `YOUR_ALPHA_VANTAGE_API_KEY` |
| `qdrant` | HTTP Request (Qdrant) | `http://192.168.1.20:6333/collections/mem0_768d/points/scroll` | Replace `YOUR_QDRANT_API_KEY` |
| `youtube` | HTTP Request (YouTube) | `https://www.googleapis.com/youtube/v3/search` | Replace `YOUR_YOUTUBE_API_KEY` |
| `social` | HTTP Request (Reddit) | `https://www.reddit.com/search.json` | No auth required — ready |

### Activation Checklist

- [ ] Fill in missing API keys (Alpha Vantage, Qdrant, YouTube) in the n8n node configs
- [ ] Manually connect each MCP Trigger → HTTP Request node in the UI (right-side `main` output to left-side input)
- [ ] Toggle workflow to **Active** in n8n
- [ ] Confirm **Settings → Available in MCP** is ON
- [ ] Register the n8n MCP endpoint in Paperclip's agent tool config

### Connection Note

The MCP Trigger's **right-side** output (`main`) connects to the HTTP Request node. The **bottom "Tools"** port is for LangChain Tool wrapper nodes — do not use it for HTTP Request chains.

## Related Docs

- [Paperclip Local Company Handbook](runbooks/paperclip-local-company-handbook.md)
- [Paperclip Local Company Usage Guide](runbooks/paperclip-local-company-usage-guide.md)
- `docs/agentic-architecture-implementation.md`
- `docs/paperclip-role-policy-bootstrap.md`
- `tasks.md`
