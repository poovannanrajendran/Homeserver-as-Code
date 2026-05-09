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
*   **Systemd Service:** `~/.config/systemd/user/paperclip.service` (Lingering enabled)
*   **Runtime Configuration Path:** `/home/labadmin/.paperclip/instances/default/config.json`
*   **Company Source Files:** `/home/labadmin/paperclip-company-finosafe` (Mirrored locally at `paperclip/finosafe`)

## 3. Tool Execution Layer (MCP)
Paperclip agents execute actions through a Model Context Protocol (MCP) bridge connected to **n8n**.

*   **n8n Server:** `http://192.168.1.30:5678`
*   **MCP Endpoint:** `http://192.168.1.30:5678/mcp-server/http`
*   **Bridge Config:** `/home/labadmin/.paperclip/instances/default/mcp.json`
*   **Active MCP Triggers:**
    1.  `web_search`: Live internet querying via Tavily.
    2.  `financial_data`: Ticker and volatility tracking via Alpha Vantage.
    3.  `qdrant_search`: Semantic search against the homelab `memex-knowledge` vector database.
    4.  `youtube_api`: Video metadata and upload management.
    5.  `social_cross_post`: Distribution to LinkedIn and X (Twitter).

## 4. Organizational Chart (Agents)
The company operates on a multi-perspective intelligence model. Due to current Paperclip adapter configurations, models are mapped to `codex_local` and `claude_local` wrappers, with the intent to route to high-precision APIs.

| Role | Agent Name | Adapter Target | Responsibility |
| :--- | :--- | :--- | :--- |
| **CEO** | The Strategist | GPT-5.4 | High-level planning, approval workflows, and niche selection. |
| **Head of Intelligence** | Alpha Researcher | DeepSeek R1 | Deep-dives into Qdrant/Memex history for insurance/crypto correlations. |
| **Head of Monitoring** | Market Sentry | Gemini 3.1 Flash | 24/7 monitoring of live market spikes using financial APIs. |
| **Creative Director** | Viral Writer | Claude 4.6 Sonnet | Converting technical briefs into retention-optimized narrative scripts. |
| **Head of Distribution**| Growth Hacker | Gemini 3.1 Flash | SEO optimization, thumbnail ideation, and cross-platform posting. |

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
