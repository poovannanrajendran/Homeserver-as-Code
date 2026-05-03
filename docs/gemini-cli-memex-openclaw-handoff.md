# Gemini-CLI Handoff — Memex OpenClaw Integration Fixes

Use this prompt with Gemini-CLI in the Memex repository:

```text
You are working in /Users/poovannanrajendran/Documents/GitHub/memex.

Goal: backport the live OpenClaw/Memex integration fixes that were applied directly on automation-runner-01, then test locally. Do not commit secrets. Do not edit .env except for local testing if explicitly needed.

Context:
- Live runner host: automation-runner-01 at 192.168.1.30.
- Live runner path: /home/labadmin/memex.
- Live service: memex-runner.service.
- Qdrant host: http://192.168.1.20:6333.
- Qdrant requires an API key. Code must read QDRANT_API_KEY from environment and send it as header api-key.
- Memex live MCP is forced-command SSH from OpenClaw; runner token is stored on automation-runner-01 at /etc/memex/runner_api_secret, not in OpenClaw config or SSH args.
- Qdrant collection memex-knowledge currently contains 7,478 payload-only points. This is a cache, not semantic Mem0 recall.

Required code changes:

1. Fix FastAPI route ordering in scripts/runner_api.py.
   - /wiki/synthesis/list must be registered before /wiki/{entry_type}/{slug}.
   - Current bug: /wiki/synthesis/list can be captured as entry_type=synthesis, slug=list and return 404.
   - Preserve authentication behaviour.

2. Update scripts/openclaw_ingest.py for secured Qdrant.
   - Add QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "").
   - Add helper:
     def qdrant_headers() -> dict:
         return {"api-key": QDRANT_API_KEY} if QDRANT_API_KEY else {}
   - Pass headers=qdrant_headers() on every Qdrant request:
     - GET /collections/{COLLECTION}
     - PUT /collections/{COLLECTION}
     - PUT /collections/{COLLECTION}/points
     - final verification GET
   - Keep current payload-only vector behaviour unless you are explicitly asked to implement real embeddings.
   - Update comments/docs in the script to say payload-only cache, not Mem0 semantic recall.

3. Update scripts/memex_mcp.py documentation comments.
   - Replace any sample OpenClaw config that passes RUNNER_API_SECRET in SSH args.
   - Document forced-command SSH:
     - OpenClaw config command: ssh
     - args: ["-i", "/var/lib/openclaw/.ssh/id_ed25519", "-o", "StrictHostKeyChecking=accept-new", "labadmin@192.168.1.30"]
     - authorized_keys command on runner: command="/usr/local/bin/memex-mcp-wrapper",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty <public-key>
   - Document that /usr/local/bin/memex-mcp-wrapper loads RUNNER_API_SECRET from /etc/memex/runner_api_secret.

4. Update .env.example.
   - Include:
     RUNNER_API_SECRET=change_me
     RUNNER_API_PORT=8000
     N8N_MEMEX_SYNC_URL=http://192.168.1.30:5678/webhook/memex-ingest
     QDRANT_HOST=http://192.168.1.20:6333
     QDRANT_API_KEY=
     OPENCLAW_NOTIFY_ENABLED=true
   - Do not include real keys.

5. Add or update tests if the repo has a testing pattern.
   Minimum acceptable verification if no test framework exists:
   - Add a small script or documented commands that verify route order using FastAPI TestClient or curl against a local runner.
   - Add a dry-run check for openclaw_ingest.py.

Required local verification:

Run from /Users/poovannanrajendran/Documents/GitHub/memex:

python3 -m py_compile scripts/runner_api.py scripts/openclaw_ingest.py scripts/memex_mcp.py
python3 scripts/openclaw_ingest.py --dry-run

If dependencies are available, run:

RUNNER_API_SECRET=test python3 scripts/runner_api.py

Then in another shell:

curl -s -H "Authorization: Bearer test" "http://127.0.0.1:8000/search?q=lloyds&limit=1"
curl -s -H "Authorization: Bearer test" "http://127.0.0.1:8000/wiki/synthesis/list"

Expected:
- /search returns HTTP 200 with a results array.
- /wiki/synthesis/list returns HTTP 200 with synthesis documents, not 404.

Deployment instructions to leave in HANDOFF.md or docs/openclaw-integration.md:

On automation-runner-01:

cd /home/labadmin/memex
git pull --ff-only
chmod +x scripts/memex_mcp.py
sudo systemctl restart memex-runner
sudo systemctl status memex-runner --no-pager

Endpoint verification on automation-runner-01:

TOKEN="$(sed -n 's/^RUNNER_API_SECRET=//p' /home/labadmin/memex/.env | tail -n 1)"
curl -fsS -H "Authorization: Bearer ${TOKEN}" "http://127.0.0.1:8000/search?q=lloyds&limit=1"
curl -fsS -H "Authorization: Bearer ${TOKEN}" "http://127.0.0.1:8000/wiki/synthesis/list"

Qdrant ingest verification on automation-runner-01:

cd /home/labadmin/memex
. .venv/bin/activate
python scripts/openclaw_ingest.py --dry-run

Do not run the real ingest repeatedly unless you intend to upsert/update the existing memex-knowledge collection. If recreating from scratch, delete the collection first with authenticated Qdrant DELETE.

Return a summary of files changed, tests run, and any mismatch between local repo and live runner.
```

## Follow-up After Backport

If you are asked to continue after the backport is complete, the remaining Memex/OpenClaw work is now:

- Build the n8n `Memex → Qdrant Sync` workflow in the live n8n UI on `automation-runner-01`.
- Import the current Prometheus-backed Qdrant Grafana dashboard ID `24603` instead of the stale `19812`.
- Keep treating `memex-knowledge` as a payload cache until real embeddings are added to the ingest path.

Do not claim the n8n workflow is finished unless the live UI or API has actually been verified.

## Live Runner Diff To Preserve

These are the important live changes already applied on `automation-runner-01`:

- `scripts/runner_api.py`: `/wiki/synthesis/list` route moved before `/wiki/{entry_type}/{slug}`.
- `scripts/openclaw_ingest.py`: Qdrant requests patched to send `api-key` from `QDRANT_API_KEY`.
- `/home/labadmin/memex/.env`: includes `N8N_MEMEX_SYNC_URL`, `QDRANT_HOST`, and `QDRANT_API_KEY` with real values.
- `/usr/local/bin/memex-mcp-wrapper`: loads `RUNNER_API_SECRET` from `/etc/memex/runner_api_secret`.
- `memex-runner.service`: active and serving on `127.0.0.1:8000`/`:8000`.

Do not overwrite the live runner with a repo version that lacks these fixes.
