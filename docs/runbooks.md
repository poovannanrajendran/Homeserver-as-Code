# Operations Runbook

## Standard Compose Update
```bash
scripts/update_compose_stack.sh /srv/stacks/databases
scripts/update_compose_stack.sh /srv/stacks/platform
scripts/update_compose_stack.sh /srv/stacks/observability
scripts/update_compose_stack.sh /srv/stacks/nextcloud
```

## Observability Stack (Grafana/Prometheus/Loki)
Primary deployment path:
- `/srv/stacks/observability`

Bring up/refresh:
```bash
cd /srv/stacks/observability
docker compose pull
docker compose up -d
docker compose ps
```

Access URLs:
- Grafana: `http://<runner-host>:3000`
- Prometheus: `http://<runner-host>:9090`
- Loki API: `http://<runner-host>:3100`
- Uptime Kuma: `http://<runner-host>:3002`
- Blackbox exporter: `http://<runner-host>:9115`

Health checks:
```bash
curl -fsS http://127.0.0.1:3000/api/health
curl -fsS http://127.0.0.1:9090/-/healthy
curl -fsS http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | [.labels.job,.labels.instance,.health,.lastError] | @tsv'
```

Prometheus config reload:
```bash
curl -fsS -X POST http://127.0.0.1:9090/-/reload
```

If Grafana datasource/dashboard provisioning fails on startup with:
`Datasource provisioning error: data source not found`
use API import mode:
```bash
/srv/stacks/observability/scripts/import_homeserver_dashboard.sh
```
This imports `homeserver-health.json` directly into Grafana and avoids startup-loop provisioning failures.

Extended health collector (Proxmox + VMs + Postgres sizes + Supabase + cron inventory):
```bash
cd /srv/stacks/observability
mkdir -p scripts textfile

# copy script + env template from repo
cp -f stacks/observability/scripts/host_checks.sh /srv/stacks/observability/scripts/host_checks.sh
cp -f stacks/observability/scripts/host_checks.env.example /srv/stacks/observability/scripts/host_checks.env
chmod +x /srv/stacks/observability/scripts/host_checks.sh
chmod 600 /srv/stacks/observability/scripts/host_checks.env

# edit secrets/endpoints in env, then run once
vi /srv/stacks/observability/scripts/host_checks.env
/srv/stacks/observability/scripts/host_checks.sh

# install 5-min cron
cp -f stacks/observability/scripts/install_host_checks_cron.sh /srv/stacks/observability/scripts/install_host_checks_cron.sh
chmod +x /srv/stacks/observability/scripts/install_host_checks_cron.sh
/srv/stacks/observability/scripts/install_host_checks_cron.sh

# verify metrics file
cat /srv/stacks/observability/textfile/host_checks.prom
```

What this emits:
- `obs_proxmox_https_up`
- `obs_ping_up`, `obs_ssh_up` (for PVE + VM100/101/103)
- `obs_postgres_query_ok`, `obs_postgres_db_size_bytes` (lloyds/memex/youtube/supabase)
- `obs_filesystem_used_percent`
- `obs_cron_jobs_total`
- `obs_mongo_atlas_tcp_up`
- `obs_supabase_configured`
- `obs_qdrant_http_up`

Qdrant monitoring:
```bash
# on automation-runner-01
grep obs_qdrant_http_up /srv/stacks/observability/textfile/host_checks.prom
curl -fsS http://127.0.0.1:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job=="qdrant") | [.labels.job,.labels.instance,.health,.lastError] | @tsv'
```

Qdrant health uses `/readyz` or `/healthz`. Do not use `/health`; Qdrant 1.17.1 returns 404 there.

Important: data volume permissions
- `grafana-data`, `prometheus-data`, and `loki-data` must be writable by the container runtime users.
- If services boot-loop with permission errors, fix and restart:
```bash
sudo chmod -R 0777 /srv/stacks/observability/grafana-data /srv/stacks/observability/prometheus-data /srv/stacks/observability/loki-data
cd /srv/stacks/observability
docker compose restart grafana prometheus loki
```

## OpenClaw + Memex Memory Stack

Hosts:
- OpenClaw: `ai-node-01` (`192.168.1.24`)
- Qdrant: `docker-host-01` (`192.168.1.20`)
- Memex runner API: `automation-runner-01` (`192.168.1.30`)

OpenClaw checks:
```bash
ssh labadmin@192.168.1.24
sudo -u openclaw openclaw health --json
sudo -u openclaw openclaw agents list --json
sudo -u openclaw openclaw agents bindings --json
sudo -u openclaw openclaw mcp list
sudo -u openclaw -H sh -lc 'set -a; . /etc/openclaw/mem0.env; openclaw mem0 status --json'
sudo /usr/local/bin/memory_health.sh
```

Note:
- Mem0 namespaces are logical today. The shared Qdrant collection is `mem0_768d`, and agent scoping is carried in payload `user_id` values like `poovi:agent:wayne`.
- OpenClaw control UI no longer uses browser basic auth on the tailnet path; access is network-only via the OpenClaw gateway config (`gateway.auth.mode = token`, device auth disabled).

Important paths:
- OpenClaw config: `/var/lib/openclaw/.openclaw/openclaw.json`
- OpenClaw home: `/var/lib/openclaw`
- Mem0 env: `/etc/openclaw/mem0.env`
- Agent instructions: `/var/lib/openclaw/.openclaw/agents/<agent>/agent/AGENTS.md`
- Telegram route: `fury` is explicitly bound to `telegram` account `default`; `workspace-fury/BOOTSTRAP.md` should be absent after seeding, and `IDENTITY.md`, `USER.md`, and `MEMORY.md` should be present in the workspace.
- Agent split for publishing: `fury` only routes; `loki` owns LinkedIn drafting. Publishing is a separate archive step that consumes the draft artifact and stores the successful post to Mem0.
- LinkedIn flow is now split into two durable steps:
  - `scripts/openclaw_linkedin_draft.sh` calls `loki` and saves a draft artifact under `output/linkedin/drafts/`
  - `scripts/openclaw_linkedin_archive.sh` archives a successful publish into Mem0 and saves a published record under `output/linkedin/published/`
  - The handoff between write and publish is the draft artifact, not chat context
  - Draft artifacts are stable JSON documents with `artifactType: linkedin_draft`, `schemaVersion`, `id`, `content`, `contentHash`, `prompt`, `source`, and `draftOutput.textPayloads`
  - Published records use `artifactType: linkedin_published`, keep the same `content` and `contentHash`, add `sourceDraft` for traceability, and record memory outcome under `memory.status`, `memory.archived`, `memory.result`, and `memory.error`
  - If Mem0/Qdrant is slow or unauthorised, the archive helper still saves the local published record and surfaces the memory failure in the JSON
- Terminal bridges for testing: `scripts/openclaw_send.sh` sends a prompt to Telegram, `scripts/openclaw_agent_turn.sh` runs a direct agent turn from terminal and auto-falls back to `--local` if the gateway rejects the device identity, `scripts/openclaw_session_latest.sh` inspects the newest session for an agent, and `scripts/openclaw_session_follow.sh` waits for the next update and prints a one-line summary.
- Memory health script: `/usr/local/bin/memory_health.sh`
- Memory health cron: `/etc/cron.d/openclaw-memory-health`

Qdrant checks:
```bash
ssh labadmin@192.168.1.20
cd /srv/stacks/databases
KEY="$(sed -n 's/^QDRANT_API_KEY=//p' .env | tail -n 1)"
curl -fsS -H "api-key: ${KEY}" http://192.168.1.20:6333/readyz
curl -fsS -H "api-key: ${KEY}" http://192.168.1.20:6333/collections
```

Memex runner checks:
```bash
ssh labadmin@192.168.1.30
systemctl status memex-runner --no-pager
TOKEN="$(sed -n 's/^RUNNER_API_SECRET=//p' /home/labadmin/memex/.env | tail -n 1)"
curl -fsS -H "Authorization: Bearer ${TOKEN}" "http://127.0.0.1:8000/search?q=lloyds&limit=1"
curl -fsS -H "Authorization: Bearer ${TOKEN}" "http://127.0.0.1:8000/wiki/synthesis/list"
```

Known caveats:
- Memex `memex-knowledge` in Qdrant is payload-only. Use MCP `memex_search`/`memex_get` for semantic working context.
- The live OpenClaw schema rejects `agents.list[*].plugins`; do not document or apply per-agent Mem0 config overrides until OpenClaw supports them.
- Mem0 CLI add/search hung during the local Ollama smoke test. Treat Mem0 as connected but not fully auto-capture-verified until a real conversation test passes.
- Telegram memory validation should use a plain message, then a fresh session recall prompt. If the bot answers like a bootstrap shell, check that `workspace-fury/BOOTSTRAP.md` is gone and the workspace has the seeded `IDENTITY.md`, `USER.md`, and `MEMORY.md` files.

## Paperclip Local Company

Use the local Paperclip company docs for Mac-side model planning and test prompts:

- [Paperclip Local Company Handbook](runbooks/paperclip-local-company-handbook.md)
- [Paperclip Local Company Usage Guide](runbooks/paperclip-local-company-usage-guide.md)

Recommended reading:

1. Read the handbook first for the provider/model matrix and the qwen3.5:27b benchmark result.
2. Read the usage guide for safe prompts and a first end-to-end test.
3. Keep the local company separate from the production Paperclip control plane on `automation-runner-01`.

## Paperclip FinOSafe Remote Company

Use these docs for the remote FinOSafe company on `automation-runner-01` only:

- [FinOSafe Handoff](runbooks/paperclip-finosafe-handoff.md)
- [FinOSafe Recovery and Validation Runbook](runbooks/paperclip-finosafe-recovery-validation.md)
- [FinOSafe PRD](products/prd-finosafe-paperclip.md)
- [FinOSafe Blockers and Fixes](products/blockers-finosafe-paperclip.md)

Important live paths:

- Paperclip URL: `http://192.168.1.30:3101`
- n8n URL: `http://192.168.1.30:5678`
- FinOSafe working directory: `/home/labadmin/paperclip-company-finosafe`
- Live instance: `/home/labadmin/.paperclip-worktrees/instances/finosafe-live`
- n8n MCP proxy: `/home/labadmin/bin/finosafe-n8n-mcp.py`

## OpenClaw Discord Channel

Live state on `ai-node-01`:
- OpenClaw runtime: `2026.6.8 (844f405)`
- Discord plugin: `@openclaw/discord`
- Gateway auth: `gateway.auth.mode = token`
- Discord token source: `DISCORD_BOT_TOKEN` loaded from `~/.env`
- Discord bot: `@OpenClaw_D`
- Guild allowlist: `1490345277020704789`
- Allowlisted user: `841706877473914931`
- Test channel: `#openclaw_d` (`1500957397512880349`)
- Route binding: top-level `bindings[]` entry mapping Discord channel `#openclaw_d` to `fury`

Useful commands:
```bash
ssh labadmin@192.168.1.24
set -a; . ~/.env; set +a
openclaw gateway stop
openclaw gateway
openclaw channels status --probe
openclaw channels list
openclaw channels resolve --channel discord '#openclaw_d' --json
openclaw channels logs --channel discord | tail -80
```

Smoke test:
- In `#openclaw_d`, mention the bot and send `@OpenClaw_D reply with exactly: ready`.
- If the route is healthy, the bot should type and reply through the `fury` binding.

Troubleshooting:
- If `openclaw channels status --probe` reports `secret unavailable`, re-check that `DISCORD_BOT_TOKEN` is exported in the same shell that starts the gateway.
- If `openclaw gateway` exits with `EADDRINUSE`, kill the stale listener on `127.0.0.1:18789` before restarting.
- If Discord is connected but `agents` shows `(none)`, the problem is usually a missing top-level `bindings[]` route, not bot auth.
- Keep the Discord token out of chat and out of the repo. Use `~/.env` or another local secret file instead.

## Nextcloud: Enable Web Updater
```bash
# on the host running the Nextcloud compose stack
scripts/nextcloud_enable_web_updater.sh /srv/stacks/nextcloud
```

- Web updater UI: `http://<nextcloud-host>:8082/updater`

## Nextcloud: config.php Not Read / Initialized Error
If you see: `Configuration was not read or initialized correctly, not overwriting /var/www/html/config/config.php`

1. Check container logs:
```bash
cd /srv/stacks/nextcloud
docker compose logs --tail=200 nextcloud
```
2. Validate the config file parses (run inside the container):
```bash
cd /srv/stacks/nextcloud
docker compose exec -T -u www-data -w /var/www/html nextcloud php -l /var/www/html/config/config.php
```
3. If MariaDB is in a separate compose stack, set DB host explicitly (service names do not resolve across projects):
- Set `NEXTCLOUD_MYSQL_HOST=host.docker.internal` in `/srv/stacks/nextcloud/.env`
- Then restart Nextcloud:
```bash
cd /srv/stacks/nextcloud
docker compose up -d
```
4. If `config.php` is corrupted/empty from a failed init, re-init it (forces the installer again):
```bash
cd /srv/stacks/nextcloud
docker compose down
sudo cp -a /srv/data/nextcloud/html/config/config.php /srv/data/nextcloud/html/config/config.php.bak.$(date +%F_%H%M%S) || true
sudo rm -f /srv/data/nextcloud/html/config/config.php
docker compose up -d
```

## Nextcloud Background Jobs (Cron)
If Nextcloud reports background jobs not executing, run it in cron mode.

Recommended approach for Docker Compose deployments: add a `cron` sidecar container that runs `/cron.sh`.

Verification:
- In Nextcloud UI: `Settings -> Administration -> Basic settings -> Background jobs` should be `Cron`.
- In Docker: `docker ps` should show a running `nextcloud-cron` container.

## SMTP Relay (Postfix) for App Emails
This homelab uses a simple internal SMTP relay (Postfix) to send app emails (password resets, notifications, etc.) via an upstream provider.

Notes:
- If a client refuses to send because of TLS certificate trust, either:
  - disable inbound STARTTLS on the relay (plain SMTP for trusted internal networks), or
  - issue a certificate the client trusts (preferred long-term).

### Nextcloud Email Settings (Docker-Internal)
When Nextcloud and `smtp-relay` share a Docker network, configure Nextcloud to use the relay by container name:
- Server: `smtp-relay`
- Port: `587`
- Encryption: `None/STARTTLS` (works even if the relay doesn't offer STARTTLS)
- Authentication: `Off`

## Jenkins Initial Admin Password
```bash
sudo cat /srv/data/platform/jenkins/secrets/initialAdminPassword
```

## n8n Uses Postgres Check
```bash
docker exec -it n8n env | grep '^DB_TYPE='
```

## Automation Runner: Postgres LAN Access (Lloyds + Dashboard Clients)
The automation-runner Postgres is managed by:
- Compose file: `/opt/runner/deploy/docker-compose.yml`
- Service container: `automation-postgres`

Recommended bind for both local app access and LAN access:
- `0.0.0.0:5432:5432`

Apply/update:
```bash
sudo sed -i 's/127.0.0.1:5432:5432/0.0.0.0:5432:5432/' /opt/runner/deploy/docker-compose.yml
cd /opt/runner/deploy
sudo docker compose up -d postgres
```

Verify listener + container mapping:
```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep automation-postgres
sudo ss -lntp | grep ':5432'
```

Important:
- Do not bind only to `192.168.1.30:5432` if the app still uses `POSTGRES_HOST=localhost`.
- Binding only to a specific LAN IP can break loopback/localhost connections inside the host runtime.

LAN check from another machine:
```bash
nc -vz 192.168.1.30 5432
```

Lloyds digest DB dry-run check (no full digest execution):
```bash
cd /opt/automation/lloyds-market-news-digest
sudo -u codex_agent_agent /home/codex_agent_agent/miniconda3/bin/conda run -n 314 python - <<'PY'
import psycopg
from pymongo import MongoClient

# Postgres dry check
with psycopg.connect("<redacted>", connect_timeout=10) as c:
    with c.cursor() as cur:
        cur.execute("select 1")
        print("postgres_ping:", cur.fetchone())

# Mongo dry check
m = MongoClient("<redacted>", serverSelectionTimeoutMS=10000)
print("mongo_ping:", m.admin.command("ping").get("ok"))
PY
```

## YouTube: Category/Tag Enrichment on `ai-node-01`
Production scheduling for YouTube category/tag enrichment is on `ai-node-01` (not on the operator Mac).

Runtime paths on `ai-node-01`:
- Script: `/home/codex_agent_agent/youtube_enrichment/youtube_enrich_categories_tags_v2.py`
- Runner: `/home/codex_agent_agent/youtube_enrichment/run_enrichment.sh`
- Env: `/home/codex_agent_agent/youtube_enrichment/youtube_enrich.env`
- Log: `/home/codex_agent_agent/youtube_enrichment/logs/enrichment.log`

Schedule:
- Cron entry (hourly):
```bash
0 * * * * /home/codex_agent_agent/youtube_enrichment/run_enrichment.sh >> /home/codex_agent_agent/youtube_enrichment/logs/enrichment.log 2>&1
```

Operational guarantees:
- Enrichment updates only rows with missing `categories` or `tags`.
- Existing category/tag values are not overwritten.
- Timestamp behavior is preserved (table trigger protects `youtube_added_at` on updates).
- This schedule is independent from the V5 ingestion schedule and should not disrupt V5 runtime.

Checks:
```bash
# show cron entry
ssh codex_agent_agent@ai-node-01.tail4bbda6.ts.net 'crontab -l | grep youtube_enrichment/run_enrichment.sh'

# run one-shot and inspect summary
ssh codex_agent_agent@ai-node-01.tail4bbda6.ts.net '/home/codex_agent_agent/youtube_enrichment/run_enrichment.sh && tail -n 40 /home/codex_agent_agent/youtube_enrichment/logs/enrichment.log'
```

## Backup Preflight
```bash
scripts/backup_preflight.sh
```

## Outline (Family Wiki)
See `docs/outline.md`.

## Jellyfin (LXC) First Login
```bash
# inside media LXC container (Debian/Ubuntu)
# Install Jellyfin (use distro packages or Jellyfin's official repo for newer versions)
sudo apt update
sudo apt install -y jellyfin
sudo systemctl enable --now jellyfin
```

- Open `http://<media-host>:8096` and complete the setup wizard.
- Add Jellyfin libraries:
  - Movies: `/media/movies`
  - TV Shows: `/media/tv`
  - Music: `/media/music`
  - Home Videos: `/media/home-videos`
  - Photos: `/media/photos`

## Jellyfin Hardware Transcoding (Intel/AMD) - VM (Legacy)
1. On Proxmox host, verify GPU render nodes exist:
   ```bash
   ls -l /dev/dri
   ```
2. Pass iGPU through to the media VM (example VMID `104`):
   ```bash
   qm set 104 --hostpci0 0000:00:02,pcie=1
   ```
3. Reboot the VM and verify:
   ```bash
   ls -l /dev/dri
   ```
4. On the media VM, verify group IDs:
   ```bash
   getent group render
   getent group video
   ```
5. In Jellyfin UI: `Dashboard -> Playback -> Transcoding`, enable VA-API and select `/dev/dri/renderD128`.

## Jellyfin Hardware Transcoding (Intel/AMD) - LXC
1. Stop the media container and edit `/etc/pve/lxc/<CTID>.conf` on Proxmox host:
   ```ini
   lxc.cgroup2.devices.allow: c 226:* rwm
   lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
   ```
2. Start the container and verify:
   ```bash
   ls -l /dev/dri
   ```
3. Inside the container, ensure the `jellyfin` user can access render/video devices:
   ```bash
   sudo usermod -aG render,video jellyfin
   sudo systemctl restart jellyfin
   ```
4. In Jellyfin UI: enable VA-API and set render device `/dev/dri/renderD128`.
