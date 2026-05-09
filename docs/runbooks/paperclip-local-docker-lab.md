# Paperclip Local Docker Lab

## Purpose

This runbook defines the local Docker Paperclip lab on the MacBook Pro. It is for safe experimentation before promoting patterns to the production Paperclip instance on `automation-runner-01`.

## Design Decision

Use a self-contained Postgres container instead of the existing Postgres on `192.168.1.20`.

Rationale:

- Keeps lab data isolated from shared homelab databases.
- Makes reset simple with Docker volumes.
- Makes upgrade testing safer: back up the lab DB, rebuild the Paperclip image, restart.
- Avoids accidentally writing test companies into production/shared infrastructure.
- Keeps secrets and tokens scoped to the lab `.env`.

Trade-off:

- It is not the exact same topology as production Paperclip, which currently uses embedded Postgres managed by the Paperclip process.

## Location

Stack:

`stacks/paperclip-lab`

Company package:

`paperclip/poovi_papercompany`

Grounding pack mount:

`/Users/poovannanrajendran/Documents/workarea/Poovi_GroudningPack`

## Services

| Service | Purpose | Access |
| --- | --- | --- |
| `paperclip` | Paperclip lab UI/API | `http://localhost:3102` |
| `postgres` | Self-contained lab database | Docker network only |

The Compose project name is:

`paperclip-locallab`

## Data Persistence

Persistent Docker volumes:

- `paperclip_locallab_pgdata` — Postgres data
- `paperclip_locallab_home` — Paperclip instance config, logs, storage, generated JWT secret

These survive:

- `docker compose down`
- image rebuilds
- Paperclip upgrades

These are removed only with:

```bash
docker compose down -v
```

## Environment File

Copy and edit:

```bash
cd stacks/paperclip-lab
cp .env.example .env
```

Key variables:

| Variable | Purpose |
| --- | --- |
| `PAPERCLIP_VERSION` | Paperclip npm package version, `latest` by default |
| `PAPERCLIP_HOST_PORT` | Host UI port, default `3102` |
| `POSTGRES_PASSWORD` | Lab DB password |
| `N8N_MCP_URL` | Remote n8n MCP endpoint, default `http://192.168.1.20:5678/mcp-server/http` |
| `N8N_MCP_BEARER_TOKEN` | Remote n8n MCP bearer token; keep only in `.env` |
| `LOCAL_MAC_MCP_URL` | Local Mac-only HTTP MCP bridge, default `http://host.docker.internal:8765/mcp` |
| `OLLAMA_BASE_URL` | Local Mac Ollama endpoint, default `http://host.docker.internal:11434` |
| `OLLAMA_OPENAI_BASE_URL` | Ollama OpenAI-compatible endpoint, default `http://host.docker.internal:11434/v1` |
| `POOVI_GROUNDING_PACK_PATH` | Read-only host path mounted into the container |
| `ANTHROPIC_API_KEY` | Optional Claude Code API auth |
| `OPENAI_API_KEY` | Optional Codex CLI API auth |
| `GEMINI_API_KEY` | Optional Gemini CLI API auth |
| `OPENROUTER_API_KEY` | Optional OpenRouter auth for provider routing |
| `X_API_KEY` | Optional X/Twitter API key for future publishing bridges |
| `X_API_SECRET` | Optional X/Twitter API secret for future publishing bridges |

Do not commit `.env`.

## Start

```bash
cd stacks/paperclip-lab
./scripts/start.sh
```

Open:

```text
http://localhost:3102
```

## In-Container Provider CLIs

The lab image installs these commands globally so they are available anywhere inside the `paperclip` container:

- `claude`
- `gemini`
- `codex`
- `python3`
- `jq`
- `git`
- `zip` / `unzip`
- `rsync`

Verify they are present:

```bash
cd stacks/paperclip-lab
./scripts/provider-versions.sh
```

Run the lab doctor:

```bash
cd stacks/paperclip-lab
./scripts/doctor.sh
```

Show the current lab env values without leaking secrets:

```bash
cd stacks/paperclip-lab
./scripts/show-env.sh
```

Recommended auth model:

- Claude Code:
  - API key auth: set `ANTHROPIC_API_KEY` in `stacks/paperclip-lab/.env`
  - interactive auth: run `docker compose exec paperclip claude`, then use `/login`
- Codex:
  - API key auth: set `OPENAI_API_KEY` in `stacks/paperclip-lab/.env`
  - then run `docker compose exec paperclip codex`
- Gemini CLI:
  - API key auth: set `GEMINI_API_KEY` in `stacks/paperclip-lab/.env`
  - or run `docker compose exec paperclip gemini` and follow the Google login flow

Notes:

- Credentials live under `/home/paperclip` inside the container, so they persist with the `paperclip_locallab_home` volume.
- The image already includes an `xdg-open` shim, so browser-login prompts print a URL instead of crashing inside Linux.
- If you use browser auth, open the printed URL on your Mac and finish the login there.

## Status

```bash
cd stacks/paperclip-lab
./scripts/status.sh
```

Expected health:

```json
{"status":"ok","deploymentMode":"authenticated","bootstrapStatus":"bootstrap_pending"}
```

## First Login

The Docker lab runs in `authenticated/private` mode. Create the first admin invite:

```bash
cd stacks/paperclip-lab
./scripts/bootstrap-ceo.sh
```

Open the printed invite URL in the browser, sign in as the first admin user, then approve CLI access when prompted by `paperclipai auth login`.

## Import Poovi Paper Company

After first login, authenticate the CLI:

```bash
cd stacks/paperclip-lab
./scripts/login-cli.sh
```

The command prints a `/cli-auth/...` URL. Open that URL in your Mac browser, approve access, and leave the terminal command running until it returns. The container includes an `xdg-open` shim so the CLI does not crash when it tries to open a browser from inside Linux.

Then import the company:

```bash
cd stacks/paperclip-lab
./scripts/bootstrap-poovi-company.sh
```

This imports:

`paperclip/poovi_papercompany`

The company includes agents for:

- Chief of Staff
- Researcher
- Lab Engineer
- Content Strategist
- Career Strategist
- Growth Operator
- Finance Analyst
- Archivist

## Upgrade Without Losing Data

```bash
cd stacks/paperclip-lab
./scripts/upgrade.sh
```

The upgrade script:

1. Takes a Postgres backup into `stacks/paperclip-lab/backups`.
2. Rebuilds the Paperclip image.
3. Starts the stack with the existing volumes.

To pin a version, edit `.env`:

```bash
PAPERCLIP_VERSION=2026.5.2
```

Then run:

```bash
./scripts/upgrade.sh
```

## Backup

```bash
cd stacks/paperclip-lab
./scripts/backup-db.sh
```

Backups are written to:

`stacks/paperclip-lab/backups`

## Update `.env` and Recreate the Lab

Use the helper script to change a value in `.env` and immediately rebuild/recreate the `paperclip` service:

```bash
cd stacks/paperclip-lab
./scripts/update-env.sh PAPERCLIP_THEME_NAME paperclip-locallab-blue
```

Multiple updates in one call are supported:

```bash
./scripts/update-env.sh PAPERCLIP_PUBLIC_URL http://localhost:3102 OPENAI_API_KEY sk-...
```

Notes:

- The script updates `stacks/paperclip-lab/.env` on the host.
- It then runs `docker compose up -d --build --force-recreate paperclip`.
- If you change `POSTGRES_*` values after first boot, the database volume may still carry the old credentials. In that case you may need a DB reset or a fresh volume.

## Other Helpers

Single-key env update:

```bash
cd stacks/paperclip-lab
./scripts/set-env.sh OPENROUTER_API_KEY sk-or-...
```

You can also use `KEY=VALUE`:

```bash
./scripts/set-env.sh OPENROUTER_API_KEY=sk-or-...
```

Rotate the Paperclip JWT secret:

```bash
cd stacks/paperclip-lab
./scripts/rotate-secret.sh
```

Backup the lab DB and then rotate the JWT secret:

```bash
cd stacks/paperclip-lab
./scripts/backup-and-rotate.sh
```

Drop into the lab container shell:

```bash
cd stacks/paperclip-lab
./scripts/lab-shell.sh
```

Open the lab in your Mac browser:

```bash
cd stacks/paperclip-lab
./scripts/open-lab.sh
```

Rebuild only when paperclip-relevant files changed:

```bash
cd stacks/paperclip-lab
./scripts/sync-paperclip.sh
```

## Stop

```bash
cd stacks/paperclip-lab
./scripts/stop.sh
```

## Full Reset

This destroys lab data:

```bash
cd stacks/paperclip-lab
docker compose down -v
```

## MCP Integration

### Remote n8n MCP

The lab can connect to n8n on:

`http://192.168.1.20:5678/mcp-server/http`

Set in `.env`:

```bash
N8N_MCP_URL=http://192.168.1.20:5678/mcp-server/http
N8N_MCP_BEARER_TOKEN=<your token>
```

The container generates `mcp.json` at startup. The n8n MCP server is added only when the bearer token is present.

### Local Mac MCP

Docker cannot directly call arbitrary stdio MCP tools installed on the Mac. Use an HTTP/streamable MCP bridge on the Mac, then expose it to the container via:

```bash
LOCAL_MAC_MCP_URL=http://host.docker.internal:8765/mcp
```

Recommended local-only MCP tools to expose through that bridge:

- filesystem reader limited to repo and grounding pack
- GitHub/repo search
- browser automation for local UIs
- local artefact writer for drafts
- Ollama model/tool wrapper if needed

## Ollama

The lab is wired to local Mac Ollama via:

```bash
OLLAMA_BASE_URL=http://host.docker.internal:11434
OLLAMA_OPENAI_BASE_URL=http://host.docker.internal:11434/v1
```

Recommendation:

- Use Ollama for cheap draft/research experiments.
- Use an OpenAI-compatible proxy or local MCP bridge when Paperclip needs model/tool access.
- Do not route production-quality publishing through local small models without review.

## Mac Advantages To Add To Paperclip

Recommended additions:

| Capability | Why It Helps | Recommended Path |
| --- | --- | --- |
| Local Ollama | Cheap, private model tests | expose through `host.docker.internal:11434` |
| Grounding pack | High-quality personal context | read-only Docker mount |
| Docker Desktop | Fast reset and reproducible labs | Compose volumes and backup scripts |
| Local repo access | Test company packages before production import | mount selected repo paths read-only |
| Browser automation | Test local dashboards and UI flows | local MCP HTTP bridge |
| File artefact store | Save drafts, briefs, and experiments | Docker volume or repo `output/` path |
| MacBook M4 Pro | Fast local inference and builds | use Ollama + Docker builds locally |

Do not add by default:

- live social posting
- direct production n8n write tools
- unrestricted filesystem access
- production API keys

## Experimental Plugins And Artefacts

Good candidates for the lab:

- **Draft artefact plugin:** store LinkedIn drafts, career briefs, and content outlines locally.
- **Grounding pack reader:** read-only tool scoped to `/grounding/Poovi_GroundingPack`.
- **Local browser tester:** validate `localhost:3102` and other local dashboards.
- **Ollama model tester:** compare local models against hosted model outputs.
- **n8n dry-run bridge:** call n8n workflows with test payloads only.
- **Company import validator:** dry-run imports and check agent/task/skill completeness.
- **Runbook generator:** convert successful experiments into markdown runbooks.
- **Memory export artefact:** write successful insights to a local markdown file before promoting to OpenClaw/Mem0.

## Promotion Rule

Nothing from this lab should move to production until it has:

1. A short runbook.
2. A backup/rollback plan.
3. No production secrets embedded in files.
4. A clear reason to promote.
5. A dry-run result or screenshot/log evidence.
