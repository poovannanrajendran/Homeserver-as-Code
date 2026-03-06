# n8n MCP Connection (Local)

Endpoint:
- `http://192.168.1.30:5678/mcp-server/http`

Notes:
- Use header format `authorization: Bearer <TOKEN>`.
- Do not commit live tokens to git.
- If a token was shared in chat/logs, rotate it in n8n and update clients.

Config example:
- `docs/integrations/n8n-mcp-config.example.json`
