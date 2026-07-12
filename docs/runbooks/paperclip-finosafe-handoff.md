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

## 3. Important Live Paths

Use these paths when debugging or restoring the FinOSafe deployment on `automation-runner-01`.

| Purpose | Path |
| --- | --- |
| FinOSafe working directory | `/home/labadmin/paperclip-company-finosafe` |
| Paperclip user service | `/home/labadmin/.config/systemd/user/paperclip.service` |
| Paperclip service override | `/home/labadmin/.config/systemd/user/paperclip.service.d/override.conf` |
| Live Paperclip instance data | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live` |
| Live Paperclip MCP config | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live/mcp.json` |
| FinOSafe company Codex home | `/home/labadmin/.paperclip-worktrees/instances/finosafe-live/companies/2dae29b7-aa61-48e5-8ead-35c540c9f3a6/codex-home` |
| n8n MCP stdio proxy | `/home/labadmin/bin/finosafe-n8n-mcp.py` |
| n8n SQLite database | `/opt/automation/n8n/data/database.sqlite` |
| Local repo mirror | `paperclip/finosafe/` |

## 4. Current Operational State
*   **Access:** The database blocker is fully resolved. The user `poovannan@gmail.com` is an instance admin and active owner of the `FinOSafe Media Group` (`FINAA`).
*   **Security:** Paperclip is bound to the `lan` and locked down in `authenticated` mode.
*   **Tools:** The n8n workflow `Paperclip MCP Tools (FinOSafe)` is published and active. Paperclip agents reach it through the local stdio proxy at `/home/labadmin/bin/finosafe-n8n-mcp.py`.
*   **Validation:** `FINAA-9` completed successfully through the live `alpha-researcher` Codex runtime and called both n8n-backed MCP tools.
*   **Issue Board:** Old validation/recovery artifacts are closed. Live content work remains in `FINAA-1` and `FINAA-2`.

## 5. Validation Evidence

Last verified on 2026-05-11:

*   Paperclip health: `{"status":"ok","deploymentMode":"authenticated","bootstrapStatus":"ready","bootstrapInviteActive":false}`
*   Agent runtime: `alpha-researcher` completed run `f9c8f845-c07d-489b-af35-f0f2eecd6f6e`.
*   n8n workflow executions: `131` through `135` completed with `success`.
*   MCP result: `web_search` returned `Insurance News | InsuranceNewsNet`.
*   MCP result: `financial_data_api` returned AAPL price `293.3200`, latest trading day `2026-05-08`.

## 6. Next Operating Step

Assign the production content issue when ready:

*   `FINAA-1`: `daily-news-short`
*   `FINAA-2`: `niche-topic-deep-dive`

Use `alpha-researcher` for the first live research task and monitor n8n executions in `http://192.168.1.30:5678`.

## 7. Artifacts Created
*   `AI_Agent_Comparison.md`: Research comparison for NotebookLM.
*   `docs/products/prd-finosafe-paperclip.md`: Formal product requirements.
*   `docs/products/rca-gemini-cli-paperclip-deployment.md`: Root Cause Analysis of deployment blockers and Codex 5.5 fixes.
*   `docs/runbooks/paperclip-finosafe-recovery-validation.md`: Recovery and validation log for the 2026-05-10/11 runtime fixes.
*   `n8n_finosafe_tools.json`: The raw n8n workflow schema.
*   `paperclip/finosafe/`: Local mirror of the company configuration.
