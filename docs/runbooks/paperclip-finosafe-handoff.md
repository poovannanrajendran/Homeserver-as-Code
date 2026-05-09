# Handoff Document: FinOSafe Media Group Deployment

## 1. Project Goal
Launch the **FinOSafe Media Group** as a fully governed, "Zero-Human" AI organization using the Paperclip AI framework, backed by Poovi's 20-year Lloyd's of London insurance expertise.

## 2. Architecture & Services
The system spans two primary VMs in the Proxmox homelab:

*   **Automation Runner (`192.168.1.30`)**
    *   **Paperclip AI:** Running as a persistent `systemd` user service (`paperclip.service`). Accessible at `http://192.168.1.30:3101`.
    *   **n8n:** Running on port `5678`, acting as the MCP Server to bridge Paperclip to external APIs.
*   **Docker Host (`192.168.1.20`)**
    *   **Company Source Files:** The configuration for FinOSafe (Agents, Tasks, Skills) is version-controlled and originally deployed from `~/paperclip-company-finosafe`.
    *   **Qdrant:** The `memex-knowledge` vector store runs here on port `6333`.

## 3. Current Operational State
*   **Access:** The database blocker is fully resolved. The user `poovannan@gmail.com` is the active owner of the `FinOSafe Media Group` (`FINAA`).
*   **Security:** Paperclip is bound to the `lan` and locked down in `authenticated` mode.
*   **Tools:** The n8n workflow (`Paperclip MCP Tools`) has been successfully imported with the correct `@n8n/n8n-nodes-langchain.mcpTrigger` nodes and is "Available in MCP". The Paperclip server is configured via `mcp.json` to reach this n8n instance.

## 4. Immediate Next Steps for the User
To finalize the execution pipeline and start generating content, complete the following:

1.  **Configure API Keys in Paperclip:**
    *   Open `http://192.168.1.30:3101/FINAA/settings` (or the Secrets tab).
    *   Add your LLM API keys (`OPENAI_API_KEY`, `DEEPSEEK_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`) so the `codex_local` and `claude_local` wrappers can route to the high-precision models.
2.  **Configure Action Nodes in n8n:**
    *   Open your n8n dashboard (`http://192.168.1.30:5678`).
    *   Open the `Paperclip MCP Tools (FinOSafe)` workflow.
    *   Double-click the action nodes (e.g., Tavily, Alpha Vantage) and insert your respective API keys.
    *   Ensure the workflow is toggled to **Active**.
3.  **Initiate the First Task:**
    *   In the Paperclip dashboard, select the **Alpha Researcher** or **Market Sentry**.
    *   Assign the recurring task: `Daily Finance News Short`.
    *   Monitor the "Runs" tab to watch the agent successfully call the MCP tools and generate the first script!

## 5. Artifacts Created
*   `AI_Agent_Comparison.md`: Research comparison for NotebookLM.
*   `docs/products/prd-finosafe-paperclip.md`: Formal product requirements.
*   `docs/products/rca-gemini-cli-paperclip-deployment.md`: Root Cause Analysis of deployment blockers and Codex 5.5 fixes.
*   `n8n_finosafe_tools.json`: The raw n8n workflow schema.
*   `paperclip/finosafe/`: Local mirror of the company configuration.