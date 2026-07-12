# Product Requirements Document (PRD): FinOSafe Media Group

## 1. Project Objective
Transition the **FinOSafe** YouTube channel from a solo creator effort to a "Zero-Human" AI-operated media company managed by the **Paperclip AI** framework. The company will leverage Poovannan Rajendran's 20-year specialty insurance expertise (Lloyd's of London) to generate "Institutional Alpha" content for the retail crypto and finance niche.

**Primary Goal:** Achieve 100k subscribers by EOY 2026.

## 2. Infrastructure & Deployment Details
The Paperclip orchestration layer is deployed as a persistent user `systemd` service on the Proxmox homelab to ensure stability across reboots.

*   **Server Host:** `automation-runner-01`
*   **IP Address:** `192.168.1.30`
*   **Paperclip Dashboard URL:** `http://192.168.1.30:3101`
*   **Deployment Mode:** `authenticated` (Private network access, LAN binding)
*   **Systemd Service:** `/home/labadmin/.config/systemd/user/paperclip.service` (Lingering enabled)
*   **Systemd Override:** `/home/labadmin/.config/systemd/user/paperclip.service.d/override.conf`
*   **Live Instance ID:** `finosafe-live`
*   **Live Instance Path:** `/home/labadmin/.paperclip-worktrees/instances/finosafe-live`
*   **Runtime Configuration Path:** `/home/labadmin/.paperclip-worktrees/instances/finosafe-live`
*   **Company Source Files:** `/home/labadmin/paperclip-company-finosafe` (Mirrored locally at `paperclip/finosafe`)
*   **Active Company ID:** `2dae29b7-aa61-48e5-8ead-35c540c9f3a6`

## 3. Tool Execution Layer (MCP)
Paperclip agents execute actions through a Model Context Protocol (MCP) bridge connected to **n8n**.

*   **n8n Server:** `http://192.168.1.30:5678`
*   **n8n Workflow:** `Paperclip MCP Tools (FinOSafe)`
*   **n8n Workflow ID:** `OJVWHJzekaQPzihW`
*   **MCP Trigger URL Pattern:** `http://192.168.1.30:5678/mcp/<trigger-id>/sse`
*   **Important:** Do not use `/mcp-server/<trigger-id>/sse`; that route returns the n8n UI instead of the MCP SSE endpoint.
*   **Paperclip MCP Config:** `/home/labadmin/.paperclip-worktrees/instances/finosafe-live/mcp.json`
*   **Codex MCP Config:** `/home/labadmin/.paperclip-worktrees/instances/finosafe-live/companies/2dae29b7-aa61-48e5-8ead-35c540c9f3a6/codex-home/config.toml`
*   **Local n8n MCP Proxy:** `/home/labadmin/bin/finosafe-n8n-mcp.py`
*   **Active MCP Triggers:**
    1.  `web_search`: Live internet querying via Tavily.
    2.  `financial_data_api`: Ticker and volatility tracking via Alpha Vantage.
    3.  `qdrant_search`: Semantic search against the homelab `memex-knowledge` vector database.
    4.  `youtube_api`: Video metadata and upload management.
    5.  `reddit_social_search`: Social listening against Reddit.

### 3.1 Validated Trigger IDs

| Tool | n8n MCP Trigger ID |
| --- | --- |
| `web_search` | `2f8583d0-141d-487a-8adb-f062bd14301f` |
| `financial_data_api` | `276cc567-a9f3-4197-b1e0-e10b1d5e4989` |
| `qdrant_search` | `7acf451c-4642-4fab-976d-af0d44d5d6ec` |
| `youtube_api` | `9870d8f5-d0a3-4616-b075-b57c36d091c2` |
| `reddit_social_search` | `7e9c3bd3-aa4c-4796-ad0c-b3f9aeddc2cf` |

## 4. Organizational Chart (Agents)
The company operates on a multi-perspective intelligence model. Due to current Paperclip adapter configurations, models are mapped to `codex_local` and `claude_local` wrappers, with the intent to route to high-precision APIs.

| Role | Agent Name | Adapter Target | Responsibility |
| :--- | :--- | :--- | :--- |
| **CEO** | `strategist` | `codex_local` / `gpt-5.4-mini` | High-level planning, approval workflows, and niche selection. |
| **Head of Intelligence** | `alpha-researcher` | `codex_local` / `gpt-5.4-mini` | Deep-dives into Qdrant/Memex history for insurance/crypto correlations. |
| **Head of Monitoring** | `market-sentry` | `codex_local` / `gpt-5.4-mini` | Monitoring live market spikes using financial APIs. |
| **Creative Director** | `viral-writer` | `claude_local` / `claude-haiku-4-5-20251001` | Converting technical briefs into retention-optimized narrative scripts. |
| **Head of Distribution**| `growth-hacker` | `codex_local` / `gpt-5.4-mini` | SEO optimization, thumbnail ideation, and cross-platform posting. |

All specialist agents report to `strategist`.

## 5. Standard Operating Procedures (Tasks)
The company runs on two primary recurring task cycles:

1.  **Daily Finance News Short:**
    *   *Cadence:* Daily
    *   *Assignee:* Alpha Researcher
    *   *Workflow:* Identifies a 24-hour headline -> Viral Writer drafts 150 words -> Growth Hacker posts.
2.  **Niche Topic Deep-Dive:**
    *   *Cadence:* 4x Weekly (Mon: Macro, Wed: Crypto/AI, Fri: Dividends, Sat: Emerging Tech)
    *   *Assignee:* Strategist
    *   *Workflow:* Strategist picks topic -> Researcher pulls Qdrant data -> Writer drafts 2,500 words.

## 6. Proprietary Skills
*   **`lloyds-correlation`:** Instructs agents to cross-reference general market data with specialty insurance signals.
*   **`youtube-retention-hooks`:** A rigid framework forcing the Viral Writer to use negative constraints and tease the "Institutional Insight" in the first 5 seconds of the video.

## 7. Runtime Validation

The runtime path was validated on 2026-05-11 using `FINAA-9`.

*   Paperclip health: `ok`
*   Agent runtime: `alpha-researcher` completed Codex run `f9c8f845-c07d-489b-af35-f0f2eecd6f6e`
*   n8n workflow executions: `131` through `135` succeeded
*   `web_search` result: `Insurance News | InsuranceNewsNet`
*   `financial_data_api` result: AAPL price `293.3200`, latest trading day `2026-05-08`

See `docs/runbooks/paperclip-finosafe-recovery-validation.md` for the full recovery record.
