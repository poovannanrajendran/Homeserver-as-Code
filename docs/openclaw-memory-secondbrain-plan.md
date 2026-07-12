# OpenClaw — Memory & Second Brain Integration Plan

**Version:** 2.0
**Date:** 2026-05-01
**Target host:** `ai-node-01` (192.168.1.24)
**OpenClaw version at planning:** 2026.4.29 (a448042)
**Second Brain:** Memex (Quartz + FastAPI + Postgres, `memex-poovi.vercel.app`)
**Status:** Partially implemented on 2026-05-01; see live notes below

## 0. Live Implementation Notes — 2026-05-01

These notes reflect the actual OpenClaw 2026.6.8 install on `ai-node-01`.

- The active OpenClaw config file is `/var/lib/openclaw/.openclaw/openclaw.json`, not `~/.openclaw/config.json5`.
- Phase 1 was applied using the live schema: `memory-core`/`openclaw-mem0` memory slot plus `memory-wiki` bridge mode. The older `memory.backend: "honcho"` block is not valid on this install.
- Qdrant 1.17.1 does not expose `/health`; use `/healthz` or `/readyz`. Authenticated `/collections` is also a valid operational check.
- Qdrant is deployed on `docker-host-01` with API-key auth and ports bound to `192.168.1.20`.
- Mem0 plugin `@mem0/openclaw-mem0@1.0.11` uses `oss.embedder`, `oss.llm`, and `oss.vectorStore` config keys. The earlier top-level `embedder`, `llm`, and `vectorStore` example is not valid for this plugin version.
- Mem0 is configured in open-source mode with local Ollama (`nomic-embed-text`, `llama3.2:3b`) and Qdrant collection `mem0_768d`. Qdrant API key is supplied through `/etc/openclaw/mem0.env`, loaded by `openclaw-gateway.service`.
- Control UI access is network-only on the tailnet path: gateway auth is set to `none` and device auth is disabled to avoid the browser basic-auth loop.
- `plugins.entries.openclaw-mem0.hooks.allowConversationAccess: true` is required; otherwise auto-capture is blocked for the non-bundled plugin.
- The live agent schema rejects `agents.list[*].plugins`; per-agent config overrides cannot be stored there. Use Mem0 `--agent-id` namespaces and OpenClaw runtime agent IDs until the schema supports per-agent plugin config.
- `memex-runner.service` did not exist initially. It was deployed to `/home/labadmin/memex` on `automation-runner-01`.
- `runner_api.py` required a route-order fix: `/wiki/synthesis/list` must be registered before `/wiki/{entry_type}/{slug}`.
- Gemini-CLI backport completed in the Memex repo; production and local source hashes match for `runner_api.py`, `openclaw_ingest.py`, `memex_mcp.py`, and `.env.example`.
- `memex-knowledge` is a payload-only Qdrant cache with 7,478 points. It is not semantic Mem0 recall until real embeddings are added.
- `/usr/local/bin/memory_health.sh` is installed on `ai-node-01` and checks Qdrant, OpenClaw health, Mem0, memory-wiki, Memex MCP, and a real `memex_search` call.
- Grafana dashboard ID `19812` returned 404 from Grafana.com on 2026-05-01; the current Prometheus-backed Qdrant option is dashboard ID `24603`.

---

## 1. Executive Summary

This plan wires three layers of persistent and evolving memory into OpenClaw, then connects Memex — Poovi's Quartz-based Second Brain — as a live knowledge source. The result: every agent (FURY, CYBORG, WAYNE, ORACLE, BANNER, STARK, XAVIER, DEADPOOL, STRANGE, DIANA, LOKI) accumulates and recalls context automatically, and can query 7,483 Memex pages without the user re-explaining state each session.

### Memex at a Glance

| Property | Value |
|----------|-------|
| Framework | Quartz 4 (static site) + FastAPI runner API |
| Repo | `/Users/poovannanrajendran/Documents/GitHub/memex` |
| Deployed site | `https://memex-poovi.vercel.app` |
| Runner API | `memex-runner.service` on homelab (`/home/labadmin/memex`) |
| Database | Postgres (`POSTGRES_URL`) — pipeline/audit tracking |
| AI engine | Google Gemini 2.5 Pro/Flash for extraction and synthesis |
| Index | `wiki_index.json` — 7,483 pages (603 sources, 1,821 entities, 5,046 concepts, 8 synthesis) |
| Built-in OpenClaw hook | DB migration lists `'openclaw'` as valid `trigger_source` — designed for this |

### What This Delivers

| Capability | Before | After |
|-----------|--------|-------|
| Cross-session memory | Static USER.md / MEMORY.md | Auto-evolving semantic + structured |
| User modelling | None | Mem0 open-source memory plus memory-wiki structure |
| Structured knowledge | Raw markdown | memory-wiki with contradiction tracking |
| Memex Second Brain | Disconnected | Live search via MCP + incremental n8n sync; Qdrant bulk payload cache is staged for later semantic recall |
| Agent isolation | Shared context | Runtime `--agent-id` namespaces available; config-level per-agent overrides rejected by live schema |
| Content agent context | No platform memory | Platform-specific memory per ideas agent |
| Memex write-back | Manual only | Agents can create Memex source pages via runner API |

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  Telegram / CLI  →  OpenClaw Gateway (ai-node-01:18789)             │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │   fury       │  │  oracle      │  │  wayne                   │  │
│  │  (router)    │  │  (research)  │  │  (content/brand)         │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────────┘  │
│         │                 │                      │                  │
│  ┌──────▼─────────────────▼──────────────────────▼──────────────┐  │
│  │          Memory Stack (per agent, isolated namespace)         │  │
│  │                                                               │  │
│  │  Layer 3: Mem0 plugin   ←→  Qdrant (docker-host-01:6333)     │  │
│  │           AutoRecall + Auto-Capture on every turn            │  │
│  │           Collections: mem0_768d + memex-knowledge           │  │
│  │                                                               │  │
│  │  Layer 2: memory-wiki   ←→  Structured claims on disk        │  │
│  │           Contradiction tracking, freshness scores           │  │
│  │                                                               │  │
│  │  Layer 1: OpenClaw session context + agent instructions      │  │
│  └─────────────────────────────────────────────────────────────-┘  │
│                              │                                      │
│  ┌───────────────────────────▼──────────────────────────────────┐  │
│  │          Memex Second Brain Bridge                            │  │
│  │                                                               │  │
│  │  Path A (cache):    Qdrant memex-knowledge collection        │  │
│  │    7,483 pages bulk-ingested as payload-only cache           │  │
│  │                                                               │  │
│  │  Path B (live):     MCP → memex-runner API /search /wiki     │  │
│  │    Primary Memex recall path until real embeddings are added │  │
│  │                                                               │  │
│  │  Path C (sync):     n8n webhook → Qdrant incremental push    │  │
│  │    New Memex ingest → auto-pushed to Qdrant within minutes   │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

Infrastructure:
  ai-node-01         192.168.1.24   OpenClaw gateway + Mem0 + memory-wiki
  docker-host-01     192.168.1.20   Qdrant vector store
  automation-runner  192.168.1.30   memex-runner API + n8n sync workflows
  memex repo (Mac)   ~/Documents/GitHub/memex  Source of truth (markdown + wiki_index.json)
```

---

## 3. Prerequisites

| Requirement | Value | Status |
|-------------|-------|--------|
| OpenClaw version | >= 2026.4.15 | ✓ 2026.6.8 confirmed |
| Ollama running on ai-node-01 | Mem0 extraction LLM (`llama3.2:3b`) + embedding (`nomic-embed-text`) | ✓ Confirmed — Mem0 uses local Ollama, not OpenAI/Gemini |
| OpenAI / Gemini keys configured | Model routing for agents (not Mem0) | ✓ Confirmed in providers |
| docker-host-01 accessible | Qdrant target | ✓ 192.168.1.20 |
| automation-runner-01 n8n | Memex → Qdrant sync | ✓ 192.168.1.30 |
| Memex runner API | Second Brain | `memex-runner.service` on 192.168.1.30 |

---

## 4. Phase 0 — Pre-Flight Verification

**Objective:** Confirm live state before any changes.

> **PATH WARNING — read before any shell command.**
> OpenClaw runs as user `openclaw`. Its home is **not** `/home/openclaw` — it is typically `/var/lib/openclaw` on systemd-managed installs.
> `~` in your shell expands as `labadmin`, not `openclaw`. Every command that touches OpenClaw's files must use:
> ```bash
> sudo -u openclaw -H sh -lc '<command>'
> ```
> Or use the discovered absolute path from Task 0.6 below. Never use `~/.openclaw/...` directly under `sudo -u openclaw`.

### 4.1 Tasks

**Task 0.1 — Verify OpenClaw version and service health**

```bash
ssh labadmin@192.168.1.24
sudo -u openclaw openclaw --version
sudo systemctl status openclaw-gateway --no-pager
sudo -u openclaw openclaw health --json
```

Expected: version `2026.6.8`, service `active (running)`.

**Task 0.2 — Verify embedding provider is active**

```bash
sudo -u openclaw openclaw models status | grep -E "embedding|gemini|openai"
```

Embedding must be active — needed for `memory_search` and Mem0. If inactive, check OpenAI/Gemini key.

**Task 0.3 — Backup current config**

```bash
sudo -u openclaw -H sh -lc 'cp "$HOME/.openclaw/openclaw.json" "$HOME/.openclaw/openclaw.json.bak-$(date +%Y%m%d)"'
sudo -u openclaw -H sh -lc 'cat "$HOME/.openclaw/openclaw.json"'
```

Keep this backup. All subsequent phases modify config — rollback by restoring this file.

**Task 0.4 — Test docker-host-01 connectivity from ai-node-01**

```bash
ssh labadmin@192.168.1.24
curl -s http://192.168.1.20:2375/version 2>/dev/null || \
  echo "Docker API not exposed (expected) — using SSH"
ping -c 2 192.168.1.20
```

Network reachability must pass. Qdrant will bind to `192.168.1.20:6333`.

**Task 0.5 — Verify current agent list**

```bash
sudo -u openclaw openclaw agents list --bindings --json
```

Record agent IDs. Needed for Phase 4 memory scoping.

**Task 0.6 — Discover and record openclaw home directory**

```bash
OPENCLAW_HOME=$(sudo -u openclaw -H sh -lc 'echo $HOME')
echo "openclaw home: $OPENCLAW_HOME"
# Record this value — use it in place of ~ for all subsequent commands
# Typically /var/lib/openclaw or /home/openclaw
```

Record the output. Replace every `~` in subsequent steps with this absolute path.

### 4.2 Verification Gate

All five tasks must pass before proceeding. If Task 0.2 fails, stop — Mem0 and memory_search both depend on embeddings.

---

## 5. Phase 1 — Native Memory Layer

**Objective:** Enable memory-wiki (structured facts) and native memory/dreaming using the live OpenClaw schema. The earlier Honcho-style `memory.backend` block is not valid on this host.

### 5.1 Tasks

**Task 1.1 — Enable memory-wiki plugin**

Patch `/var/lib/openclaw/.openclaw/openclaw.json` on ai-node-01:

```json5
{
  plugins: {
    slots: {
      memory: "memory-wiki"
    },
    entries: {
      "memory-wiki": {
        enabled: true
      }
    }
  }
}
```

**Task 1.2 — Native memory slot**

For OpenClaw 2026.6.8, use `memory-core` initially, then `openclaw-mem0` after Phase 2. Do not add `memory.backend: "honcho"` to this host.

Historical invalid block retained below as a warning:

Add under top-level config:

```json5
{
  memory: {
    backend: "honcho"
  }
}
```

**Task 1.3 — Enable dreaming (background consolidation)**

```json5
{
  memory: {
    backend: "honcho",
    dreaming: {
      enabled: true,
      intervalMinutes: 120,
      candidateThreshold: 5
    }
  }
}
```

Dreaming runs every 2 hours when agent is idle — consolidates short-term signals into long-term memory.

**Task 1.4 — Restart and verify**

```bash
sudo systemctl restart openclaw-gateway
sudo -u openclaw openclaw health --json
sudo -u openclaw openclaw channels status --probe
```

**Task 1.5 — Smoke test memory-wiki from Telegram**

Send to `@MissionOpenClaw_bot`:

```
Remember this: I am building a multi-agent OpenClaw setup.
Agents: fury (router only), cyborg (ops), wayne (career/brand), oracle (market intel),
banner (coding), stark (brainstorm), xavier (LinkedIn ideas), deadpool (X),
strange (YouTube), diana (Instagram), loki (viral writer + LinkedIn publisher).
```

Then:

```
What agents am I building?
```

Response must recall the agent list without it being in session context.

### 5.2 Verification

```bash
# Check memory-wiki files created
sudo -u openclaw -H sh -lc 'ls "$HOME/.openclaw/workspace/memory/wiki/"'

# Check memory plugins active
sudo -u openclaw openclaw plugins inspect memory-wiki --json
sudo -u openclaw -H sh -lc 'set -a; . /etc/openclaw/mem0.env 2>/dev/null || true; openclaw mem0 status --json'
```

### 5.3 Rollback

```bash
sudo -u openclaw -H sh -lc 'cp "$HOME/.openclaw/openclaw.json.bak-YYYYMMDD" "$HOME/.openclaw/openclaw.json"'
sudo systemctl restart openclaw-gateway
```

---

## 6. Phase 2 — Vector Memory (Qdrant + Mem0)

**Objective:** Deploy Qdrant on docker-host-01, install Mem0 plugin on OpenClaw. This gives AutoRecall + Auto-Capture on every conversation turn — the real evolving memory layer.

### 6.1 Tasks

**Task 2.1 — Deploy Qdrant on docker-host-01**

SSH to docker-host-01:

```bash
ssh labadmin@192.168.1.20
```

Add to `/srv/stacks/databases/docker-compose.yml`:

```yaml
  qdrant:
    image: qdrant/qdrant:latest
    container_name: qdrant
    restart: unless-stopped
    ports:
      - "6333:6333"
      - "6334:6334"
    volumes:
      - qdrant_data:/qdrant/storage
    environment:
      - QDRANT__SERVICE__GRPC_PORT=6334
```

Also add to the `volumes:` section at the bottom:

```yaml
  qdrant_data:
```

Deploy:

```bash
cd /srv/stacks/databases
docker compose up -d qdrant
docker ps | grep qdrant
```

**Task 2.2 — Verify Qdrant is reachable**

From ai-node-01:

```bash
ssh labadmin@192.168.1.24
curl -s -H "api-key: <QDRANT_API_KEY>" http://192.168.1.20:6333/healthz
curl -s -H "api-key: <QDRANT_API_KEY>" http://192.168.1.20:6333/readyz
curl -s -H "api-key: <QDRANT_API_KEY>" http://192.168.1.20:6333/collections
```

Expected responses: `/healthz` returns `healthz check passed`, `/readyz` returns `all shards are ready`, and `/collections` returns JSON.

Also accessible from browser: `http://192.168.1.20:6333/dashboard`

**Task 2.2b — Add Qdrant API key before loading personal data**

Qdrant defaults to unauthenticated. Do this before putting any memory data in:

```yaml
# Add to qdrant service in /srv/stacks/databases/docker-compose.yml
environment:
  - QDRANT__SERVICE__GRPC_PORT=6334
  - QDRANT__SERVICE__API_KEY=<strong-random-token>   # add this
```

Also bind ports to LAN interface only — not 0.0.0.0:

```yaml
ports:
  - "192.168.1.20:6333:6333"
  - "192.168.1.20:6334:6334"
```

```bash
cd /srv/stacks/databases
docker compose up -d qdrant
# Store the API key in local/SECRETS.md on your Mac
```

All subsequent `curl` commands to Qdrant must include `-H "api-key: <token>"`.
All scripts and services that talk to Qdrant must also receive the same key via `QDRANT_API_KEY` or their native client configuration.

**Task 2.3 — Install Mem0 plugin on ai-node-01**

```bash
ssh labadmin@192.168.1.24
sudo -u openclaw openclaw plugins install @mem0/openclaw-mem0
```

**Task 2.3b — Validate Mem0 plugin schema before activating**

```bash
sudo -u openclaw openclaw plugins inspect openclaw-mem0 --json
```

Confirm the output shows `oss.vectorStore`, `oss.embedder`, and `oss.llm` as valid config keys. Also confirm how the plugin passes the Qdrant API key. In `@mem0/openclaw-mem0@1.0.11`, Qdrant uses `oss.vectorStore.config.apiKey`. If the command fails or shows a different schema, the plugin version may differ from the spec — adjust Task 2.4 config accordingly.

If the installed Mem0 plugin cannot pass a Qdrant API key, do not expose Qdrant broadly. Either:
- keep Qdrant bound to a trusted interface and firewall it to `ai-node-01` and `automation-runner-01` only, or
- put Qdrant behind a small reverse proxy that injects/validates the key for supported clients.

**Task 2.4 — Configure Mem0 in self-hosted mode**

Patch the `plugins` section in `/var/lib/openclaw/.openclaw/openclaw.json`. Store `QDRANT_API_KEY` in `/etc/openclaw/mem0.env` and load it from a systemd drop-in for `openclaw-gateway.service`.

```json5
{
  memory: {
    backend: "honcho",
    dreaming: {
      enabled: true,
      intervalMinutes: 120,
      candidateThreshold: 5
    }
  },
  plugins: {
    slots: {
      memory: "openclaw-mem0"     // Mem0 takes the memory slot; memory-wiki runs alongside
    },
    entries: {
      "memory-wiki": {
        enabled: true             // Still active as structured knowledge layer
      },
      "openclaw-mem0": {
        enabled: true,
        config: {
          mode: "open-source",
          userId: "poovi",
          oss: {
            embedder: {
              provider: "ollama",
              config: {
                model: "nomic-embed-text",
                url: "http://127.0.0.1:11434",
                embeddingDims: 768
              }
            },
            llm: {
              provider: "ollama",
              config: {
                model: "llama3.2:3b",
                url: "http://127.0.0.1:11434"
              }
            },
            vectorStore: {
              provider: "qdrant",
              config: {
                url: "http://192.168.1.20:6333",
                apiKey: "${QDRANT_API_KEY}",
                onDisk: true,
                dimension: 768,
                embeddingModelDims: 768,
                collectionName: "mem0_768d"
              }
            },
            historyDbPath: "/var/lib/openclaw/.openclaw/mem0/history.db"
          },
          topK: 8,
          searchThreshold: 0.3
        }
      }
    }
  }
}
```

**Task 2.5 — Restart and verify Mem0 active**

```bash
sudo systemctl restart openclaw-gateway
sudo -u openclaw openclaw health --json | grep -i mem0
sudo -u openclaw openclaw plugins list
```

**Task 2.6 — Smoke test AutoCapture and AutoRecall**

In Telegram, start a new session (`/new`):

```
My main Verisk client account is Markel. I manage 7 accounts total including IQUW, TMK, Travelers UK, TM HCC, Apollo, and Avatar MGA.
```

End session. Start another session (`/new`):

```
Which client is my main account at Verisk?
```

Response must say "Markel" from memory — not from session context.

Check Qdrant for stored vectors:

```bash
curl -s -H "api-key: <QDRANT_API_KEY>" http://192.168.1.20:6333/collections/mem0_768d
```

### 6.2 Verification

| Check | Command | Expected |
|-------|---------|---------|
| Qdrant running | `curl -H "api-key: <QDRANT_API_KEY>" http://192.168.1.20:6333/healthz` | 200 OK |
| Collection exists | `curl -H "api-key: <QDRANT_API_KEY>" http://192.168.1.20:6333/collections/mem0_768d` | status: green |
| Mem0 plugin active | `openclaw plugins list` | openclaw-mem0 enabled |
| Recall working | New session, ask about prior fact | Recalled correctly |

### 6.3 Rollback

```bash
# Disable Mem0 plugin only
sudo -u openclaw openclaw config set plugins.entries.openclaw-mem0.enabled false
sudo systemctl restart openclaw-gateway
# Qdrant data persists — collection survives restarts
```

---

## 7. Phase 3 — Memex Second Brain Bridge

**Objective:** Connect OpenClaw to Memex via three paths: (A) bulk ingest of all 7,483 wiki pages into Qdrant for instant recall, (B) live MCP search against the runner API for fresh queries, (C) n8n incremental sync so new Memex ingests auto-update Qdrant within minutes.

> **Key fact:** Memex DB migration already defines `trigger_source: 'openclaw'` — this integration was designed in from the start.

---

### 7.1 Path A — Bulk Ingest wiki_index.json into Qdrant

> **STATUS: PAYLOAD-ONLY — semantic recall deferred.**
> `openclaw_ingest.py` currently pushes text payload without embedding vectors. Qdrant will store the data but Mem0 cannot perform semantic similarity search against it (Mem0's collection is `mem0_768d`, not `memex-knowledge`). **Use Path B (MCP live search) as the primary Memex recall path.** Path A is useful for keyword/filter queries once real embeddings are added to the ingest script.
> To enable proper semantic recall from Path A later: add Gemini `text-embedding-004` calls in `openclaw_ingest.py`, create the collection with `size: 768`, and configure Mem0 to query `memex-knowledge` as a secondary collection.

One-time operation. Loads all 7,483 Memex pages into a dedicated Qdrant collection `memex-knowledge` as searchable payload (keyword-accessible, not yet semantically recalled by Mem0).

#### Task 3.1 — Confirm runner API host ✅ CONFIRMED

Runner host: **`automation-runner-01` at `192.168.1.30`**
Path: `/home/labadmin/memex`
Service: `memex-runner.service`
DB: `192.168.1.30:5432/memex`

#### Task 3.2 — Deploy bulk ingest script ✅ WRITTEN BY GEMINI CLI

`scripts/openclaw_ingest.py` exists in the Memex repo. Deploy to automation-runner-01:

```python
#!/usr/bin/env python3
"""
Bulk-ingest Memex wiki_index.json into Qdrant via Mem0 REST API.
Run once from local Mac or from 192.168.1.30 to seed OpenClaw memory.
"""

import json
import os
import requests
from pathlib import Path

QDRANT_HOST   = os.getenv("QDRANT_HOST", "http://192.168.1.20:6333")
QDRANT_API_KEY = os.getenv("QDRANT_API_KEY", "")
COLLECTION    = "memex-knowledge"
WIKI_INDEX    = Path(__file__).parent.parent / "wiki_index.json"
BATCH_SIZE    = 50

def qdrant_headers() -> dict:
    return {"api-key": QDRANT_API_KEY} if QDRANT_API_KEY else {}

def build_text(entry: dict, entry_type: str, slug: str) -> str:
    parts = [f"[{entry_type.upper()}] {entry.get('title', slug)}"]
    if entry.get("summary"):
        parts.append(entry["summary"])
    if entry.get("frontmatter"):
        fm = entry["frontmatter"]
        if fm.get("domain"):
            parts.append(f"Domain: {fm['domain']}")
        if fm.get("tags"):
            parts.append(f"Tags: {', '.join(fm['tags'])}")
    if entry.get("keywords"):
        parts.append(f"Keywords: {', '.join(entry['keywords'][:10])}")
    return "\n".join(parts)

def ensure_collection():
    r = requests.get(f"{QDRANT_HOST}/collections/{COLLECTION}", headers=qdrant_headers())
    if r.status_code == 404:
        requests.put(f"{QDRANT_HOST}/collections/{COLLECTION}", json={
            "vectors": {"size": 768, "distance": "Cosine"}
        }, headers=qdrant_headers())
        print(f"Created collection: {COLLECTION}")
    else:
        print(f"Collection exists: {COLLECTION}")

def ingest():
    with open(WIKI_INDEX) as f:
        index = json.load(f)

    ensure_collection()

    total = 0
    for entry_type in ["sources", "entities", "concepts", "synthesis"]:
        entries = index.get(entry_type, {})
        batch = []
        for slug, entry in entries.items():
            text = build_text(entry, entry_type, slug)
            batch.append({
                "id": f"{entry_type}:{slug}",
                "text": text,
                "metadata": {
                    "type": entry_type,
                    "slug": slug,
                    "title": entry.get("title", slug),
                    "file_path": entry.get("file_path", ""),
                    "source": "memex"
                }
            })
            if len(batch) >= BATCH_SIZE:
                push_batch(batch)
                total += len(batch)
                print(f"  {entry_type}: {total} pushed...")
                batch = []
        if batch:
            push_batch(batch)
            total += len(batch)
        print(f"  {entry_type}: done ({len(entries)} entries)")

    print(f"\nTotal ingested: {total}")

def push_batch(batch: list):
    # Uses Qdrant REST directly (no Mem0 dependency for bulk load)
    # Embeddings are generated by Qdrant's built-in fastembed if enabled,
    # otherwise push as payload only and let Mem0 handle recall.
    points = [
        {
            "id": abs(hash(item["id"])) % (10**15),
            "payload": {**item["metadata"], "text": item["text"]}
        }
        for item in batch
    ]
    requests.put(
        f"{QDRANT_HOST}/collections/{COLLECTION}/points",
        headers=qdrant_headers(),
        json={"points": points}
    )

if __name__ == "__main__":
    ingest()
```

#### Task 3.3 — Run bulk ingest from Mac

```bash
cd /Users/poovannanrajendran/Documents/GitHub/memex
pip install requests
QDRANT_HOST=http://192.168.1.20:6333 QDRANT_API_KEY=<QDRANT_API_KEY> python3 scripts/openclaw_ingest.py
```

Verify in Qdrant dashboard (`http://192.168.1.20:6333/dashboard`):
Collection `memex-knowledge` should show ~7,483 points.

---

### 7.2 Path B — Live Search via MCP (Add Endpoints to runner_api)

Extends runner_api with two new endpoints: `/search` (keyword + type filter) and `/wiki/{type}/{slug}` (full page fetch). Then wraps them as an OpenClaw MCP server.

#### Task 3.4 — Deploy updated runner_api.py ✅ WRITTEN BY GEMINI CLI

`scripts/runner_api.py` has been updated with `/search`, `/wiki/{type}/{slug}`, `/wiki/synthesis/list` endpoints and write-back support. Deploy to automation-runner-01:

```python
from typing import Literal
import json as json_lib

WIKI_INDEX_PATH = Path(__file__).parent.parent / "wiki_index.json"
_wiki_cache: dict = {}

def _load_wiki() -> dict:
    global _wiki_cache
    if not _wiki_cache:
        with open(WIKI_INDEX_PATH) as f:
            _wiki_cache = json_lib.load(f)
    return _wiki_cache

class SearchResponse(BaseModel):
    results: list
    total: int
    query: str
    type_filter: Optional[str]

@app.get("/search", response_model=SearchResponse)
async def search_wiki(
    q: str,
    type: Optional[Literal["sources", "entities", "concepts", "synthesis"]] = None,
    limit: int = 10,
    token: str = Depends(verify_token)
):
    """Full-text search across wiki_index.json."""
    index = _load_wiki()
    q_lower = q.lower()
    results = []

    sections = [type] if type else ["sources", "entities", "concepts", "synthesis"]
    for section in sections:
        for slug, entry in index.get(section, {}).items():
            text = f"{entry.get('title','')} {entry.get('summary','')} {' '.join(entry.get('keywords',[]))}"
            if q_lower in text.lower():
                results.append({
                    "type": section,
                    "slug": slug,
                    "title": entry.get("title", slug),
                    "summary": (entry.get("summary") or "")[:300],
                    "file_path": entry.get("file_path", ""),
                    "frontmatter": entry.get("frontmatter", {})
                })
            if len(results) >= limit:
                break
        if len(results) >= limit:
            break

    return {"results": results, "total": len(results), "query": q, "type_filter": type}


@app.get("/wiki/{entry_type}/{slug}")
async def get_wiki_entry(
    entry_type: Literal["sources", "entities", "concepts", "synthesis"],
    slug: str,
    token: str = Depends(verify_token)
):
    """Fetch a specific wiki entry by type and slug."""
    index = _load_wiki()
    entry = index.get(entry_type, {}).get(slug)
    if not entry:
        raise HTTPException(status_code=404, detail=f"Entry not found: {entry_type}/{slug}")

    # Also try to read the markdown file for full content
    file_path = entry.get("file_path", "")
    full_content = None
    if file_path:
        md_path = Path(__file__).parent.parent / file_path
        if md_path.exists():
            full_content = md_path.read_text()

    return {
        "type": entry_type,
        "slug": slug,
        **entry,
        "full_content": full_content
    }


@app.get("/wiki/synthesis/list")
async def list_synthesis(token: str = Depends(verify_token)):
    """List all synthesis documents — highest-value content for agents."""
    index = _load_wiki()
    return [
        {"slug": slug, "title": e.get("title", slug), "summary": (e.get("summary") or "")[:200]}
        for slug, e in index.get("synthesis", {}).items()
    ]
```

Deploy the updated runner_api:

```bash
# On 192.168.1.30
cd /home/labadmin/memex
git pull  # or copy the updated file
sudo systemctl restart memex-runner
sudo systemctl status memex-runner --no-pager
```

#### Task 3.5 — Test new endpoints

```bash
# From ai-node-01 (replace 192.168.1.30 and <TOKEN>)
curl -s -H "Authorization: Bearer <TOKEN>" \
  "http://192.168.1.30:8000/search?q=lloyds+market&type=synthesis&limit=3" | python3 -m json.tool

curl -s -H "Authorization: Bearer <TOKEN>" \
  "http://192.168.1.30:8000/wiki/synthesis/list" | python3 -m json.tool
```

#### Task 3.6 — Deploy MCP wrapper ✅ WRITTEN BY GEMINI CLI

`scripts/memex_mcp.py` exists in the Memex repo. Deploy and make executable on automation-runner-01:

```python
#!/usr/bin/env python3
"""
Minimal MCP stdio server wrapping Memex runner_api.
OpenClaw calls this as a stdio MCP server.
"""
import sys, json, os, requests

RUNNER_URL = os.getenv("MEMEX_RUNNER_URL", "http://127.0.0.1:8000")
TOKEN      = os.getenv("RUNNER_API_SECRET", "")
HEADERS    = {"Authorization": f"Bearer {TOKEN}"}

TOOLS = [
    {
        "name": "memex_search",
        "description": "Search Poovi's Memex Second Brain. Returns matching sources, entities, concepts, or synthesis docs.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search terms"},
                "type":  {"type": "string", "enum": ["sources","entities","concepts","synthesis"], "description": "Filter by content type (optional)"},
                "limit": {"type": "integer", "default": 8}
            },
            "required": ["query"]
        }
    },
    {
        "name": "memex_get",
        "description": "Fetch a specific Memex wiki entry by type and slug.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "type": {"type": "string", "enum": ["sources","entities","concepts","synthesis"]},
                "slug": {"type": "string"}
            },
            "required": ["type", "slug"]
        }
    },
    {
        "name": "memex_synthesis_list",
        "description": "List all Memex deep-dive synthesis documents. Use this first to find relevant synthesis before fetching full content.",
        "inputSchema": {"type": "object", "properties": {}}
    }
]

def handle(req: dict) -> dict:
    method = req.get("method")
    rid    = req.get("id")

    if method == "initialize":
        return {"jsonrpc":"2.0","id":rid,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"memex","version":"1.0"}}}

    if method == "tools/list":
        return {"jsonrpc":"2.0","id":rid,"result":{"tools": TOOLS}}

    if method == "tools/call":
        name   = req["params"]["name"]
        args   = req["params"].get("arguments", {})
        try:
            if name == "memex_search":
                params = {"q": args["query"], "limit": args.get("limit", 8)}
                if args.get("type"):
                    params["type"] = args["type"]
                r = requests.get(f"{RUNNER_URL}/search", params=params, headers=HEADERS, timeout=10)
                content = r.json()
            elif name == "memex_get":
                r = requests.get(f"{RUNNER_URL}/wiki/{args['type']}/{args['slug']}", headers=HEADERS, timeout=10)
                content = r.json()
            elif name == "memex_synthesis_list":
                r = requests.get(f"{RUNNER_URL}/wiki/synthesis/list", headers=HEADERS, timeout=10)
                content = r.json()
            else:
                content = {"error": f"Unknown tool: {name}"}
        except Exception as e:
            content = {"error": str(e)}

        return {"jsonrpc":"2.0","id":rid,"result":{"content":[{"type":"text","text":json.dumps(content)}]}}

    return {"jsonrpc":"2.0","id":rid,"error":{"code":-32601,"message":f"Method not found: {method}"}}

if __name__ == "__main__":
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            resp = handle(req)
        except Exception as e:
            resp = {"jsonrpc":"2.0","id":None,"error":{"code":-32700,"message":str(e)}}
        sys.stdout.write(json.dumps(resp) + "\n")
        sys.stdout.flush()
```

```bash
chmod +x /home/labadmin/memex/scripts/memex_mcp.py
```

#### Task 3.7 — Register memex MCP server in OpenClaw

On ai-node-01, add to `/var/lib/openclaw/.openclaw/openclaw.json`:

```json5
{
  mcp: {
    servers: {
      "memex": {
        command: "ssh",
        args: [
          "-i", "<OPENCLAW_HOME>/.ssh/id_ed25519",   // replace with actual home from Task 0.6
          "-o", "StrictHostKeyChecking=accept-new",   // pins on first connect; never blindly accepts
          "labadmin@192.168.1.30"
          // secret NOT in args — loaded by wrapper script on runner
        ]
      }
    }
  }
}
```

> **Setup:** OpenClaw runs as user `openclaw` on ai-node-01. The RUNNER_API_SECRET must NOT appear in SSH args (visible via `ps aux`). Use a wrapper script on the runner instead.

```bash
# Step 1 — On ai-node-01: generate key using correct home (Task 0.6 result)
sudo -u openclaw -H sh -lc 'mkdir -p "$HOME/.ssh" && ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N ""'
sudo -u openclaw -H sh -lc 'cat "$HOME/.ssh/id_ed25519.pub"'
# Copy the public key output

# Step 2 — On 192.168.1.30: create restricted wrapper script
sudo tee /usr/local/bin/memex-mcp-server > /dev/null << 'EOF'
#!/bin/bash
set -e
export MEMEX_RUNNER_URL=http://127.0.0.1:8000
export RUNNER_API_SECRET=$(cat /etc/memex/runner_api_secret)
exec python3 /home/labadmin/memex/scripts/memex_mcp.py
EOF
sudo chmod 755 /usr/local/bin/memex-mcp-server
sudo mkdir -p /etc/memex
echo "<RUNNER_API_SECRET_VALUE>" | sudo tee /etc/memex/runner_api_secret > /dev/null
sudo chown labadmin:labadmin /etc/memex/runner_api_secret
sudo chmod 400 /etc/memex/runner_api_secret

# Step 3 — On 192.168.1.30: add key to authorized_keys with forced command
echo 'command="/usr/local/bin/memex-mcp-server",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty <paste public key here>' \
  >> ~/.ssh/authorized_keys

# Step 4 — On ai-node-01: test the forced command executes via SSH
sudo -u openclaw -H sh -lc 'echo "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}" | ssh -i "$HOME/.ssh/id_ed25519" labadmin@192.168.1.30'
# Should return JSON with tool list — the forced command runs automatically
```

#### Task 3.8 — Restart and verify MCP tools available

```bash
# On ai-node-01
sudo systemctl restart openclaw-gateway
sudo -u openclaw openclaw mcp list
sudo -u openclaw openclaw mcp show memex
```

**Smoke test from Telegram:**

```
Search my Memex for synthesis documents about Lloyd's market and AI.
```

```
What does my Memex say about multi-agent frameworks?
```

---

### 7.3 Path C — Incremental Sync via n8n

When Memex ingests new content, it pushes the new page to Qdrant automatically — no manual re-ingest needed.

#### Task 3.9 — Verify post-ingest webhook in watcher.py ✅ WRITTEN BY GEMINI CLI

`scripts/watcher.py` has been updated with `notify_openclaw()` called after git push. Set env var and redeploy:

```python
import httpx

N8N_WEBHOOK_URL = os.getenv("N8N_MEMEX_SYNC_URL", "")

async def notify_n8n_sync(entry_type: str, slug: str, entry: dict):
    if not N8N_WEBHOOK_URL:
        return
    async with httpx.AsyncClient() as client:
        await client.post(N8N_WEBHOOK_URL, json={
            "event": "memex_ingested",
            "type": entry_type,
            "slug": slug,
            "title": entry.get("title", slug),
            "summary": entry.get("summary", ""),
            "file_path": entry.get("file_path", ""),
            "trigger_source": "openclaw"
        }, timeout=5)
```

Call `notify_n8n_sync` at the end of the ingest pipeline when a new page is written.

#### Task 3.10 — Build n8n workflow: "Memex → Qdrant Sync"

Access n8n: `http://192.168.1.30:5678`

```
Trigger: Webhook (POST)  →  URL: /webhook/memex-ingest

Node 1: Code — Build Qdrant payload
  Input: webhook body (type, slug, title, summary, file_path)
  Output: Qdrant point with payload

Node 2: HTTP Request → Qdrant upsert
  PUT http://192.168.1.20:6333/collections/memex-knowledge/points
  Header: api-key: <QDRANT_API_KEY>
  Body: { "points": [ { "id": <hash>, "payload": { ...entry } } ] }

Node 3: Telegram notification (optional)
  Message: "Memex sync: {slug} added to Qdrant"
```

Set env in runner_api:

```bash
# Add to /home/labadmin/memex/.env — idempotent (won't duplicate on re-run)
SYNC_URL="N8N_MEMEX_SYNC_URL=http://192.168.1.30:5678/webhook/memex-ingest"
grep -qF "$SYNC_URL" /home/labadmin/memex/.env || echo "$SYNC_URL" >> /home/labadmin/memex/.env
```

Restart memex-runner after .env change:

```bash
sudo systemctl restart memex-runner
```

#### Task 3.11 — Test incremental sync

Drop a new raw file into Memex `raw/` folder and trigger ingest:

```bash
curl -s -X POST http://192.168.1.30:8000/run \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"trigger_source": "openclaw"}'
```

Check n8n execution log for the webhook trigger. Check Qdrant for the new point.

---

### 7.4 Phase 3 Verification

| Check | Command / Location | Expected |
|-------|-------------------|---------|
| Qdrant `memex-knowledge` collection | `http://192.168.1.20:6333/dashboard` | ~7,483 points |
| `/search` endpoint returns results | `curl .../search?q=lloyds` | JSON results array |
| MCP server registered | `openclaw mcp list` | `memex` listed |
| Agent searches Memex from Telegram | Send search query | Returns relevant Memex titles |
| n8n webhook fires on ingest | n8n executions log | Success on new ingest |
| Qdrant updated after ingest | Collection point count | Increments |

---

## 8. Phase 4 — Per-Agent Memory Scoping

**Objective:** Isolate each agent's memory namespace in Qdrant. Prevents oracle's Lloyd's research polluting wayne's positioning knowledge.

### 8.1 Tasks

**Task 4.1 — Install agent instruction files with OpenClaw ownership**

Run this from your Mac. It copies each local instruction file to `ai-node-01`, then installs it as `AGENTS.md` owned by the `openclaw` service user. The matching workspace seed files (`IDENTITY.md`, `USER.md`, and `MEMORY.md`) should also exist for each agent workspace before seeding turns are run.

```bash
for agent in fury cyborg wayne oracle banner xavier deadpool strange diana loki stark; do
  scp "/Users/poovannanrajendran/workarea/codex_workarea/proxmox_home_server/docs/agents/${agent}.md" \
    "labadmin@192.168.1.24:/tmp/${agent}.md"
  ssh labadmin@192.168.1.24 \
    "sudo -u openclaw -H sh -lc 'mkdir -p \"\$HOME/.openclaw/agents/${agent}/agent\"' && \
     sudo install -o openclaw -g openclaw -m 600 /tmp/${agent}.md \
       \$(sudo -u openclaw -H sh -lc 'printf %s \"\$HOME\"')/.openclaw/agents/${agent}/agent/AGENTS.md && \
     rm -f /tmp/${agent}.md"
done
```

Verify on `ai-node-01`:

```bash
sudo -u openclaw -H sh -lc 'find "$HOME/.openclaw/agents" -name AGENTS.md -maxdepth 4 -ls'
```

Do not use plain `scp` directly into `~/.openclaw/...`; that creates `labadmin`-owned files which may not be readable by OpenClaw.

**Task 4.2 — Add per-agent Mem0 userId overrides**

> **Live schema note (2026-05-01):** `agents.list[*].plugins` is rejected by OpenClaw 2026.6.8. Do not apply the JSON5 block below on the current host. It is retained as design intent. Use Mem0 CLI `--agent-id <agent>` namespaces for manual memory operations until OpenClaw supports per-agent plugin overrides in config.

```json5
{
  agents: {
    list: [
      {
        id: "fury",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-fury" }
            }
          }
        }
      },
      {
        id: "cyborg",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-cyborg" }
            }
          }
        }
      },
      {
        id: "wayne",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-wayne" }
            }
          }
        }
      },
      {
        id: "oracle",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: {
                userId: "poovi-oracle",
                topK: 12,         // more context for research agent
                threshold: 0.30   // slightly broader recall for research
              }
            }
          }
        }
      },
      {
        id: "banner",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-banner" }
            }
          }
        }
      },
      {
        id: "xavier",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-xavier" }
            }
          }
        }
      },
      {
        id: "deadpool",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-deadpool" }
            }
          }
        }
      },
      {
        id: "strange",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-strange" }
            }
          }
        }
      },
      {
        id: "diana",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-diana" }
            }
          }
        }
      },
      {
        id: "loki",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: {
                userId: "poovi-loki",
                topK: 10
              }
            }
          }
        }
      },
      {
        id: "stark",
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: {
                userId: "poovi-stark",
                topK: 15,       // broadest recall — brainstorm needs maximum context
                threshold: 0.25 // lower threshold — cast wide net for ideas
              }
            }
          }
        }
      }
    ]
  }
}
```

**Task 4.3 — Seed oracle memory with Lloyd's context**

After restart, from Telegram:

```
/subagents spawn oracle
Seed your memory with this context:
Poovi covers the Lloyd's/London Market. Key accounts: Markel, IQUW, TMK,
Travelers UK, TM HCC, Apollo, Avatar MGA. Daily digest reaches 2,600 followers.
Focus: specialty insurance, reinsurance, MGA growth, AI adoption in underwriting,
Lloyd's Blueprint Two progress, regulation (FCA/PRA), claims inflation.
Remember this for all future research sessions.
```

**Task 4.4 — Seed wayne memory with positioning**

```
/subagents spawn wayne
Seed your memory:
Poovi = 20+ years Lloyd's domain + hands-on AI builder. 31 Vercel apps in production.
Daily News Digest, 2,600+ LinkedIn followers. Senior AM at Verisk.
Comp floor £130K. Target: AI leadership role in Lloyd's market or insurtech.
Brand: The Lloyd's professional who builds AI — not just talks about it.
UK English always.
```

**Task 4.5 — Seed STARK with cross-domain context**

```
/subagents spawn stark
Seed your memory:
You are STARK — the brainstorming agent for Poovi.
Poovi's domains: Lloyd's/insurance (20+ years), AI engineering (31 Vercel apps),
personal productivity, podcast (Mahabharata Moments, 88+ episodes), homelab ops.
When brainstorming: think across all domains simultaneously.
Surface non-obvious connections. Challenge assumptions. Generate 10 ideas before
filtering to 3. Always ask: what would Tony Stark build here?
```

**Task 4.6 — Restart and verify collections in Qdrant**

```bash
sudo systemctl restart openclaw-gateway
curl -s -H "api-key: <QDRANT_API_KEY>" http://192.168.1.20:6333/collections | python3 -m json.tool
```

Each Mem0 `--agent-id` namespace is scoped separately by Mem0. In the live build, that scope is visible in Qdrant payloads as `user_id: poovi:agent:<agent>` inside the shared `mem0_768d` collection; the live OpenClaw config schema does not create separate per-agent collections via `agents.list[*].plugins`.

Decision: retain the shared `mem0_768d` collection model for now. Logical isolation via `user_id` is sufficient for the current setup; revisit separate physical collections only if we need stricter operational boundaries later.

### 8.2 Verification

```bash
# Check agent-specific memory collections
curl -s -H "api-key: <QDRANT_API_KEY>" http://192.168.1.20:6333/collections

# Verify oracle recall seeded context
sudo -u openclaw openclaw agent --agent oracle \
  --message "What is my content focus for Lloyd's research?" \
  --json
```

---

## 9. Phase 5 — Observability & Health

**Objective:** Add monitoring for the memory stack so degradation is caught early.

### 9.1 Tasks

**Task 5.1 — Add Qdrant to Prometheus scrape config**

Prometheus lives on **automation-runner-01 (192.168.1.30)**. Qdrant is on docker-host-01 (192.168.1.20) — scraped remotely.

SSH to automation-runner-01 and edit `/srv/stacks/observability/prometheus/prometheus.yml`:

```yaml
  - job_name: 'qdrant'
    static_configs:
      - targets: ['192.168.1.20:6333']
    metrics_path: '/metrics'
    authorization:
      # Qdrant accepts Authorization bearer tokens as well as the api-key header.
      # The secret file is mounted into the Prometheus container from:
      # /srv/stacks/observability/prometheus/secrets/qdrant_api_key
      credentials_file: /etc/prometheus/secrets/qdrant_api_key
```

Restart Prometheus on automation-runner-01:

```bash
ssh labadmin@192.168.1.30
cd /srv/stacks/observability
docker compose restart prometheus
```

**Task 5.2 — Add Qdrant health check to host_checks.sh**

On **automation-runner-01**, add to `/srv/stacks/observability/scripts/host_checks.sh`.
Qdrant is remote (docker-host-01) — check via LAN address, not localhost:

```bash
# Requires QDRANT_API_KEY in /srv/stacks/observability/scripts/host_checks.env
# Qdrant vector store health (on docker-host-01 — checked remotely)
QDRANT_STATUS=$(curl -s -H "api-key: ${QDRANT_API_KEY}" -o /dev/null -w "%{http_code}" http://192.168.1.20:6333/readyz)
if [ "$QDRANT_STATUS" != "200" ]; then
  echo "CRITICAL: Qdrant not responding (HTTP $QDRANT_STATUS)"
fi
```

**Task 5.3 — Add Grafana dashboard import for Qdrant**

Qdrant has a current Prometheus-backed Grafana dashboard (ID: `24603`).

```bash
# Browser: http://192.168.1.30:3000
# Dashboards → Import → ID 24603
# Grafana is on automation-runner-01 (192.168.1.30)
```

**Task 5.4 — Memory health probe script**

This script checks OpenClaw internals — it runs **on ai-node-01**, not on the runner.
Create `/usr/local/bin/memory_health.sh` on ai-node-01 (`labadmin@192.168.1.24`):

```bash
#!/bin/bash
# Run on ai-node-01 — checks all OpenClaw memory components

echo "=== OpenClaw Memory Health ==="

# 1. Qdrant (on docker-host-01 — remote check)
QDRANT_STATUS=$(curl -s -H "api-key: ${QDRANT_API_KEY}" -o /tmp/qdrant-readyz.out -w "%{http_code}" http://192.168.1.20:6333/readyz 2>/dev/null)
echo "Qdrant: HTTP $QDRANT_STATUS $(cat /tmp/qdrant-readyz.out 2>/dev/null)"

# 2. Mem0 plugin
MEM0=$(sudo -u openclaw openclaw plugins list --json 2>/dev/null | \
  python3 -c "import sys,json; \
  plugins=json.load(sys.stdin); \
  mem0=[p for p in plugins if 'mem0' in p.get('id','')]; \
  print('enabled' if mem0 and mem0[0].get('enabled') else 'disabled')")
echo "Mem0 plugin: $MEM0"

# 3. memory-wiki files (use -H to get correct openclaw home)
WIKI_COUNT=$(sudo -u openclaw -H sh -lc 'ls "$HOME/.openclaw/workspace/memory/wiki/"*.md 2>/dev/null | wc -l')
echo "memory-wiki entries: $WIKI_COUNT"

# 4. Memex MCP
MCP=$(sudo -u openclaw openclaw mcp list 2>/dev/null | grep memex | wc -l)
echo "Memex MCP server: $([ "$MCP" -gt 0 ] && echo 'configured' || echo 'not found')"

# 5. memex-runner API through forced-command MCP
sudo -u openclaw -H bash -c \
  'printf "%s\n" "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/call\",\"params\":{\"name\":\"memex_search\",\"arguments\":{\"query\":\"lloyds\",\"limit\":1}}}" |
   timeout 25 ssh -i /var/lib/openclaw/.ssh/id_ed25519 -o BatchMode=yes -o StrictHostKeyChecking=accept-new labadmin@192.168.1.30' |
  python3 -c 'import json,sys; d=json.load(sys.stdin); text=d.get("result",{}).get("content",[{}])[0].get("text",""); print("memex_search ok" if "results" in text.lower() else "memex_search FAIL")'

echo "=== Done ==="
```

```bash
sudo chmod +x /usr/local/bin/memory_health.sh
QDRANT_API_KEY=<QDRANT_API_KEY> sudo -E /usr/local/bin/memory_health.sh
```

**Task 5.5 — Add memory_health to cron (optional)**

```bash
# Run daily at 07:00 — sends result to Telegram if failures detected
crontab -e
# Add:
# 0 7 * * * QDRANT_API_KEY=<QDRANT_API_KEY> /usr/local/bin/memory_health.sh 2>&1 | \
#   grep -i "fail\|error\|disabled" && \
#   curl -s "https://api.telegram.org/bot<TOKEN>/sendMessage" \
#     -d "chat_id=5753819446" \
#     -d "text=Memory health check failed. Run memory_health.sh on ai-node-01."
```

### 9.2 Verification

| Check | Command | Expected |
|-------|---------|---------|
| Qdrant metrics in Prometheus | `http://192.168.1.30:9090/targets` | qdrant job UP |
| Qdrant Grafana dashboard | `http://192.168.1.30:3000` → Import ID 24603 | Collections, vectors, latency visible |
| Memory health script passes | `QDRANT_API_KEY=<QDRANT_API_KEY> sudo -E /usr/local/bin/memory_health.sh` on ai-node-01 | No FAIL/error lines |

---

## 10. Full Config Reference

Live config reference for OpenClaw 2026.6.8 on `ai-node-01`.

> **Do not use the older `~/.openclaw/config.json5` examples as deployment truth on this host.**
> The active file is `/var/lib/openclaw/.openclaw/openclaw.json`. Use `openclaw config patch --dry-run` before every change.
>
> The live schema accepts global plugin config but rejects `agents.list[*].plugins`, so per-agent Mem0 overrides in the historical block below are design intent only, not deployable config.

Current live essentials:

```json5
{
  mcp: {
    servers: {
      memex: {
        command: "ssh",
        args: [
          "-i", "/var/lib/openclaw/.ssh/id_ed25519",
          "-o", "StrictHostKeyChecking=accept-new",
          "labadmin@192.168.1.30"
        ]
      }
    }
  },
  plugins: {
    slots: { memory: "openclaw-mem0" },
    entries: {
      "memory-wiki": { enabled: true },
      "openclaw-mem0": {
        enabled: true,
        hooks: { allowConversationAccess: true },
        config: {
          mode: "open-source",
          userId: "poovi",
          autoCapture: true,
          autoRecall: true,
          searchThreshold: 0.3,
          topK: 8,
          oss: {
            embedder: {
              provider: "ollama",
              config: {
                model: "nomic-embed-text",
                url: "http://127.0.0.1:11434",
                embeddingDims: 768
              }
            },
            llm: {
              provider: "ollama",
              config: {
                model: "llama3.2:3b",
                url: "http://127.0.0.1:11434"
              }
            },
            vectorStore: {
              provider: "qdrant",
              config: {
                url: "http://192.168.1.20:6333",
                apiKey: "${QDRANT_API_KEY}",
                onDisk: true,
                dimension: 768,
                embeddingModelDims: 768,
                collectionName: "mem0_768d"
              }
            },
            historyDbPath: "/var/lib/openclaw/.openclaw/mem0/history.db"
          }
        }
      }
    }
  }
}
```

Current live agent list:

```text
fury (default), cyborg, wayne, oracle, banner, xavier, deadpool, strange, diana, loki, stark
```

Historical target shape retained below for design context only.

> **Note:** This is the structural reference. Merge carefully with your existing config — do not wholesale replace. Replace `<OPENCLAW_HOME>` with the absolute path discovered in Task 0.6. Replace `<QDRANT_API_KEY>` with the Qdrant key stored in `local/SECRETS.md`.
>
> In this config, `~` appears only inside OpenClaw-owned config values (`workspace`, `agentDir`). OpenClaw should expand those relative to the OpenClaw runtime user. If your version does not, replace each `~` with `<OPENCLAW_HOME>`.

```json5
{
  // --- Memory stack ---
  memory: {
    backend: "honcho",
    dreaming: {
      enabled: true,
      intervalMinutes: 120,
      candidateThreshold: 5
    }
  },

  // --- MCP servers ---
  // Uses a forced-command SSH key. The runner API secret is stored on
  // automation-runner-01 in /etc/memex/runner_api_secret and is never
  // passed in SSH args or OpenClaw config.
  mcp: {
    servers: {
      "memex": {
        command: "ssh",
        args: [
          "-i", "<OPENCLAW_HOME>/.ssh/id_ed25519",
          "-o", "StrictHostKeyChecking=accept-new",
          "labadmin@192.168.1.30"
        ]
      }
    }
  },

  // --- Plugins ---
  plugins: {
    slots: {
      memory: "openclaw-mem0"
    },
    entries: {
      "memory-wiki": {
        enabled: true
      },
      "openclaw-mem0": {
        enabled: true,
        config: {
          mode: "open-source",
          userId: "poovi",
          vectorStore: {
            provider: "qdrant",
            config: {
              host: "192.168.1.20",
              port: 6333,
              apiKey: "<QDRANT_API_KEY>",  // confirm exact key name from plugin schema
              collectionName: "openclaw-memory"
            }
          },
          embedder: {
            provider: "gemini",
            config: { model: "text-embedding-004" }
          },
          llm: {
            provider: "openai",
            config: { model: "gpt-4o-mini" }
          },
          topK: 8,
          threshold: 0.35
        }
      }
    }
  },

  // --- Agents ---
  agents: {
    defaults: {
      subagents: {
        model: "deepseek/deepseek-chat",
        runTimeoutSeconds: 900,
        archiveAfterMinutes: 60,
        maxSpawnDepth: 2,
        maxChildrenPerAgent: 4,
        maxConcurrent: 6,
        requireAgentId: true
      }
    },
    list: [
      {
        id: "fury",
        default: true,
        name: "FURY — Commander",
        workspace: "~/.openclaw/workspace-fury",
        agentDir: "~/.openclaw/agents/fury/agent",
        subagents: {
          allowAgents: [
            "cyborg", "wayne", "oracle", "banner", "stark",
            "xavier", "deadpool", "strange", "diana", "loki"
          ]
        },
        plugins: {
          entries: { "openclaw-mem0": { config: { userId: "poovi-fury" } } }
        }
      },
      {
        id: "cyborg",
        name: "CYBORG — Ops",
        workspace: "~/.openclaw/workspace-cyborg",
        agentDir: "~/.openclaw/agents/cyborg/agent",
        model: "deepseek/deepseek-chat",
        sandbox: { mode: "all", scope: "agent" },
        tools: {
          allow: ["read", "exec", "sessions_list", "sessions_history"],
          deny: ["browser", "canvas", "apply_patch"]
        },
        plugins: {
          entries: { "openclaw-mem0": { config: { userId: "poovi-cyborg" } } }
        }
      },
      {
        id: "wayne",
        name: "WAYNE — Career & Brand",
        workspace: "~/.openclaw/workspace-wayne",
        agentDir: "~/.openclaw/agents/wayne/agent",
        model: "deepseek/deepseek-chat",
        sandbox: { mode: "all", scope: "agent" },
        tools: {
          allow: ["read", "sessions_list", "sessions_history"],
          deny: ["exec", "write", "edit", "apply_patch", "browser", "canvas"]
        },
        plugins: {
          entries: { "openclaw-mem0": { config: { userId: "poovi-wayne" } } }
        }
      },
      {
        id: "oracle",
        name: "ORACLE — Market Intel",
        workspace: "~/.openclaw/workspace-oracle",
        agentDir: "~/.openclaw/agents/oracle/agent",
        model: "deepseek/deepseek-chat",
        sandbox: { mode: "all", scope: "agent" },
        tools: {
          allow: ["read", "browser", "sessions_list", "sessions_history"],  // browser needed for market research
          deny: ["exec", "write", "edit", "apply_patch", "canvas"]
        },
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-oracle", topK: 12, threshold: 0.30 }
            }
          }
        }
      },
      {
        id: "banner",
        name: "BANNER — Coding",
        workspace: "~/.openclaw/workspace-banner",
        agentDir: "~/.openclaw/agents/banner/agent",
        model: "openrouter/anthropic/claude-haiku-4-5-20251001",
        sandbox: { mode: "all", scope: "session" },
        tools: {
          allow: ["read", "write", "edit", "sessions_list", "sessions_history"],
          deny: ["exec", "browser", "canvas", "apply_patch"]
        },
        plugins: {
          entries: { "openclaw-mem0": { config: { userId: "poovi-banner" } } }
        }
      },
      {
        id: "xavier",
        name: "XAVIER — LinkedIn Ideas",
        workspace: "~/.openclaw/workspace-xavier",
        agentDir: "~/.openclaw/agents/xavier/agent",
        model: "google/gemini-2.5-flash",
        sandbox: { mode: "all", scope: "session" },
        tools: {
          allow: ["read"],
          deny: ["exec", "write", "edit", "apply_patch", "browser", "canvas"]
        },
        plugins: {
          entries: { "openclaw-mem0": { config: { userId: "poovi-xavier" } } }
        }
      },
      {
        id: "deadpool",
        name: "DEADPOOL — X Ideas",
        workspace: "~/.openclaw/workspace-deadpool",
        agentDir: "~/.openclaw/agents/deadpool/agent",
        model: "xai/grok-3-mini",
        sandbox: { mode: "all", scope: "session" },
        tools: {
          allow: ["read"],
          deny: ["exec", "write", "edit", "apply_patch", "browser", "canvas"]
        },
        plugins: {
          entries: { "openclaw-mem0": { config: { userId: "poovi-deadpool" } } }
        }
      },
      {
        id: "strange",
        name: "STRANGE — YouTube Ideas",
        workspace: "~/.openclaw/workspace-strange",
        agentDir: "~/.openclaw/agents/strange/agent",
        model: "openai/gpt-4o-mini",
        sandbox: { mode: "all", scope: "session" },
        tools: {
          allow: ["read"],
          deny: ["exec", "write", "edit", "apply_patch", "browser", "canvas"]
        },
        plugins: {
          entries: { "openclaw-mem0": { config: { userId: "poovi-strange" } } }
        }
      },
      {
        id: "diana",
        name: "DIANA — Instagram Ideas",
        workspace: "~/.openclaw/workspace-diana",
        agentDir: "~/.openclaw/agents/diana/agent",
        model: "deepseek/deepseek-chat",
        sandbox: { mode: "all", scope: "session" },
        tools: {
          allow: ["read"],
          deny: ["exec", "write", "edit", "apply_patch", "browser", "canvas"]
        },
        plugins: {
          entries: { "openclaw-mem0": { config: { userId: "poovi-diana" } } }
        }
      },
      {
        id: "loki",
        name: "LOKI — Viral Writer",
        workspace: "~/.openclaw/workspace-loki",
        agentDir: "~/.openclaw/agents/loki/agent",
        model: "openrouter/anthropic/claude-haiku-4-5-20251001",
        sandbox: { mode: "all", scope: "session" },
        tools: {
          allow: ["read"],
          deny: ["exec", "write", "edit", "apply_patch", "browser", "canvas"]
        },
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-loki", topK: 10 }
            }
          }
        }
      },
      {
        id: "stark",
        name: "STARK — Brainstorm",
        workspace: "~/.openclaw/workspace-stark",
        agentDir: "~/.openclaw/agents/stark/agent",
        model: "openrouter/anthropic/claude-sonnet-4-6",
        sandbox: { mode: "all", scope: "session" },
        tools: {
          allow: ["read", "browser", "sessions_list", "sessions_history"],
          deny: ["exec", "write", "edit", "apply_patch", "canvas"]
        },
        subagents: {
          allowAgents: ["oracle", "banner", "xavier", "deadpool", "strange", "diana"],
          maxSpawnDepth: 2
        },
        plugins: {
          entries: {
            "openclaw-mem0": {
              config: { userId: "poovi-stark", topK: 15, threshold: 0.25 }
            }
          }
        }
      }
    ]
  },

  // --- Channel bindings ---
  bindings: [
    { agentId: "fury", match: { channel: "telegram", accountId: "default" } }
    // Phase 2 channel bindings added here when separate Telegram bots created
  ]
}
```

---

## 11. Rollback Reference

| Phase | Rollback Action |
|-------|----------------|
| Phase 1 | Restore `openclaw.json.bak-YYYYMMDD`; restart gateway |
| Phase 2 | Set `plugins.entries.openclaw-mem0.enabled: false`; Qdrant data persists (safe) |
| Phase 3A (bulk ingest) | Delete `memex-knowledge` collection: `curl -X DELETE -H "api-key: <QDRANT_API_KEY>" http://192.168.1.20:6333/collections/memex-knowledge` |
| Phase 3B (MCP) | Remove `mcp.servers.memex` block; restart gateway; MCP server process ends |
| Phase 3C (n8n sync) | Disable n8n "Memex → Qdrant Sync" workflow in UI; remove `N8N_MEMEX_SYNC_URL` from .env |
| Phase 4 | Remove per-agent plugin overrides; agents fall back to default `userId: "poovi"` |

---

## 12. Implementation Checklist

### Phase 0 — Pre-Flight

- [x] **0.1** OpenClaw version confirmed 2026.6.8 (844f405)
- [x] **0.2** Embedding provider active — local Ollama (`nomic-embed-text`)
- [x] **0.3** Config backed up before changes
- [x] **0.4** ai-node-01 → docker-host-01 network reachable
- [x] **0.5** Agent list recorded — 11 agents, `fury` default
- [x] **0.6** openclaw home confirmed: `/var/lib/openclaw`; config: `openclaw.json` (not `config.json5`)

### Phase 1 — Native Memory

- [x] **1.1** memory-wiki plugin enabled in config
- [x] **1.2** Native memory slot configured using live schema (`memory-core`, then `openclaw-mem0`)
- [x] **1.3** Dreaming enabled while `memory-core` was active; Mem0 now owns the memory slot
- [x] **1.4** Gateway restarted, health check passes
- [x] **1.5** Smoke test: agent recalls fact from prior session

### Phase 2 — Vector Memory

- [x] **2.1** Qdrant added to databases stack on docker-host-01
- [x] **2.2** Qdrant health endpoint returns 200 from ai-node-01 (`/healthz`, `/readyz`)
- [x] **2.2b** Qdrant API key set; ports bound to `192.168.1.20` not `0.0.0.0`
- [x] **2.3** Mem0 plugin installed
- [x] **2.3b** `openclaw plugins inspect openclaw-mem0 --json` confirms live schema
- [x] **2.4** Mem0 config added with Qdrant + Ollama embedder/LLM
- [x] **2.5** Gateway restarted, Mem0 shows active
- [x] **2.6** Telegram memory smoke test passes after explicit `fury` binding + bootstrap cleanup; `basil-77-aurora` stored and recalled

### Phase 3 — Memex Second Brain Bridge

**Path A — Bulk Ingest**
- [x] **3.1** Runner host confirmed: `automation-runner-01` at `192.168.1.30`
- [x] **3.2** `scripts/openclaw_ingest.py` written by Gemini CLI — deploy via git pull on runner
- [x] **3.3** Bulk ingest run — `memex-knowledge` collection shows 7,478 payload-only points in Qdrant

**Path B — Live MCP Search**
- [x] **3.4** `/search`, `/wiki/{type}/{slug}`, `/wiki/synthesis/list` endpoints written by Gemini CLI — redeploy memex-runner.service
- [x] **3.5** memex-runner restarted, new endpoints tested with curl on runner
- [x] **3.6** `scripts/memex_mcp.py` MCP wrapper written by Gemini CLI — `chmod +x` on runner
- [x] **3.7** SSH key generated for `openclaw` user on ai-node-01, added to runner `authorized_keys` with forced command
- [x] **3.8** MCP config added to OpenClaw config (`mcp.servers.memex`)
- [x] **3.9** Gateway restarted, `openclaw mcp list` shows `memex`
- [x] **3.10** Telegram Memex MCP smoke test passes; `memex_synthesis_list` returned top 3 synthesis titles

**Path C — Incremental n8n Sync**
- [x] **3.11** `watcher.py` webhook written by Gemini CLI — set `N8N_MEMEX_SYNC_URL` in live `.env`, restart memex-runner
- [x] **3.12** n8n "Memex → Qdrant Sync" webhook workflow built and activated
- [x] **3.13** End-to-end test: new raw file ingested → n8n fires → Qdrant point count increases

### Phase 4 — Per-Agent Scoping

- [x] **4.1** Agent instruction files installed as `AGENTS.md`, owned by `openclaw:openclaw`, mode `600`
- [ ] **4.2** Per-agent config overrides rejected by live OpenClaw schema; use Mem0 `--agent-id` namespaces until supported in config
- [x] **4.3** oracle seeded with Lloyd's context
- [x] **4.4** wayne seeded with positioning context
- [x] **4.5** stark seeded with cross-domain brainstorming context
- [x] **4.6** Qdrant namespace visible per agent via payload `user_id` (`poovi:agent:<agent>`) inside the shared `mem0_768d` collection

### Phase 5 — Observability

- [x] **5.1** Qdrant added to Prometheus scrape targets on `automation-runner-01`
  - Prometheus reads the Qdrant API key from `/srv/stacks/observability/prometheus/secrets/qdrant_api_key` on the runner.
  - The secret must be readable by the Prometheus container user (`nobody:nogroup`, mode `0400`).
- [x] **5.2** Qdrant authenticated readiness check added to `host_checks.sh`
- [x] **5.3** Grafana Qdrant dashboard imported from Grafana.com dashboard ID 24603
- [x] **5.4** `memory_health.sh` created and passes
- [x] **5.5** Cron health check configured at `/etc/cron.d/openclaw-memory-health`

---

## 13. Known Caveats

| Issue | Detail | Mitigation |
|-------|--------|-----------|
| Mem0 topK token cost | 8 memories injected per turn = ~200–400 extra tokens | Keep topK ≤ 10; use gpt-4o-mini for extraction |
| Qdrant API key required | Port 6333/6334 bound to LAN; unauthenticated by default | Add `QDRANT__SERVICE__API_KEY` env var (Task 2.2b). Include `-H "api-key: <token>"` on all curl commands. |
| Bulk ingest no semantic vectors | `openclaw_ingest.py` pushes payload only — no embeddings | Path A = keyword lookup only. Semantic recall via Memex uses Path B (MCP) exclusively. To fix: add `text-embedding-004` calls in ingest script and push 768-dim vectors. |
| Mem0 collection mismatch | Mem0 targets `mem0_768d`; bulk ingest targets `memex-knowledge` | Mem0 will not auto-recall Memex content. MCP (`memex_search`) is the only Memex recall path until multi-collection Mem0 is configured or `memex-knowledge` receives real embeddings. |
| Per-agent config overrides unsupported | Live OpenClaw 2026.6.8 rejects `agents.list[*].plugins` | Use Mem0 CLI `--agent-id <agent>` namespaces for manual operations. Do not apply per-agent plugin override JSON until the schema supports it. |
| Telegram bootstrap state | Telegram was routed to `fury` while `BOOTSTRAP.md` was still present in `workspace-fury`, which caused the fresh-workspace reply and blocked auto-memory validation | Bind Telegram explicitly to `fury`, remove the bootstrap file after seeding identity/user/soul files, and rerun the memory smoke test |
| memory-wiki + Mem0 overlap | Both try to write memory | They complement: wiki = structured/provenance; Mem0 = semantic/auto. Not a conflict. |
| MCP over SSH latency | Each MCP tool call opens SSH, adds ~100–300ms | Acceptable for on-demand queries. Batch queries via `/search?limit=10`. |
| runner_api token not in config | `RUNNER_API_SECRET` stored in `/etc/memex/runner_api_secret` on runner (owned by `labadmin`, mode 400) | Never put secrets in SSH args (visible via `ps aux`). Wrapper script loads from file via forced-command SSH. |
| openclaw user home varies | On systemd installs, openclaw home is `/var/lib/openclaw`, not `/home/openclaw` | Always use `sudo -u openclaw -H sh -lc '...'`. Discover path via Task 0.6. |
| Agent files need correct ownership | Files scp'd as labadmin won't be readable by openclaw | Use `sudo install -o openclaw -g openclaw -m 600 <file> <dest>` not plain scp. |
| Synthesis docs (8 only) | Synthesis is the highest-value content but sparsely populated | Use `memex_synthesis_list` tool first, then fall back to concept/entity search |
| Observability stack host | Grafana/Prometheus on automation-runner-01 (192.168.1.30), NOT docker-host-01 | Grafana: `http://192.168.1.30:3000`. Prometheus: `http://192.168.1.30:9090`. CLAUDE.md was wrong — now corrected. |
