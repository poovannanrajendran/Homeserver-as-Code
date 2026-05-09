# Paperclip Local Company Handbook

This handbook documents the local Paperclip company for Poovi's Mac lab and the provider/model strategy behind it.

## Scope

This applies to the local Docker Paperclip company:

- company: `Poovi Paper Company`
- repo path: `paperclip/poovi_papercompany`
- local lab UI: `http://localhost:3102/P00/dashboard`
- grounding pack mount: `/grounding/Poovi_GroundingPack`

Use this setup for private testing, prompt validation, and agent design work before promoting anything to a production environment.

## Current Agent Layout

The current company config uses wrapper adapters:

| Agent | Current adapter | Current model label | Current budget | Current permission mode |
| --- | --- | --- | --- | --- |
| `chief-of-staff` | `claude_local` | `claude-code-local` | `$2/day` | tools: `qdrant_search`, `local_mac_mcp`, `n8n_remote` |
| `researcher` | `codex_local` | `codex-local` | `$2/day` | tools: `web_search`, `qdrant_search`, `local_mac_mcp`, `n8n_remote` |
| `lab-engineer` | `codex_local` | `codex-local` | `$2/day` | tools: `local_mac_mcp`, `docker_lab_status`, `ollama_local` |
| `content-strategist` | `claude_local` | `claude-code-local` | `$1/day` | approval required |
| `career-strategist` | `claude_local` | `claude-code-local` | `$1/day` | approval required |
| `growth-operator` | `codex_local` | `codex-local` | `$1/day` | approval required |
| `finance-analyst` | `codex_local` | `codex-local` | `$1/day` | approval required |
| `archivist` | `codex_local` | `codex-local` | `$1/day` | tools: `local_mac_mcp`, `qdrant_search` |

This is serviceable, but it is still generic. The better design is role-specific provider/model selection.

## Benchmark Result: qwen3.5:27b

I tested `qwen3.5:27b` locally on the 24 GB unified-memory Mac.

Observed behaviour:

- Ollama reported the model as `Q4_K_M`
- runtime memory footprint was about `22 GB`
- the machine had only a few hundred MB of free memory while it was active
- the run showed heavy compression pressure and did not behave like a comfortable always-on model

Recommendation:

- do not use `qwen3.5:27b` as a default agent model on this Mac
- only use it for occasional heavyweight offline runs
- prefer smaller Ollama models for always-on local roles

Best local fallback candidates on this machine:

- `qwen2.5:14b`
- `qwen2.5-coder:latest`
- `deepseek-r1:14b`
- `llama3.2:latest`
- `phi4-mini`

## Recommended Provider / Model Matrix

The goal is to map each role to the provider family that actually fits the job.

| Agent | Recommended provider | Recommended model | Why |
| --- | --- | --- | --- |
| `chief-of-staff` | Claude direct or OpenRouter Claude | `claude-3-5-haiku-20241022` | fast routing, strict instruction following, low latency |
| `researcher` | Gemini or Ollama | `gemini-2.5-flash` or `qwen2.5:14b` | fast synthesis; local fallback available |
| `lab-engineer` | Codex | `gpt-5.4` or `gpt-5.4-mini` | best fit for code and tool-heavy work |
| `content-strategist` | Claude | `claude-3-5-haiku-20241022` or `claude-sonnet-4-6` | best prose quality and brand voice control |
| `career-strategist` | Claude | `claude-sonnet-4-6` | stronger long-form positioning and profile writing |
| `growth-operator` | Gemini | `gemini-2.5-flash` | quick ideation and iteration |
| `finance-analyst` | Ollama | `qwen2.5:14b` or `deepseek-r1:14b` | keep finance work local and private |
| `archivist` | Ollama | `llama3.2:latest` or `phi4-mini` | cheap summarisation and indexing |

## Provider Notes

### Claude

Best use:

- orchestration
- writing
- high-trust policy-heavy prompts

Use Claude for:

- `chief-of-staff`
- `content-strategist`
- `career-strategist`

Preferred model family:

- `claude-3-5-haiku-20241022` for fast routing
- `claude-sonnet-4-6` for higher-quality writing

### Gemini

Best use:

- fast synthesis
- structured ideation
- short turnaround research summaries

Use Gemini for:

- `researcher`
- `growth-operator`

Preferred model:

- `gemini-2.5-flash`

### Codex

Best use:

- code changes
- shell/tool-heavy workflows
- debugging local lab automation

Use Codex for:

- `lab-engineer`

Preferred model:

- `gpt-5.4`
- `gpt-5.4-mini` if cost and latency matter more than depth

### Ollama

Best use:

- private local work
- cheap repeatable tasks
- offline fallback

Use Ollama for:

- `finance-analyst`
- `archivist`
- local fallback for `researcher`

Preferred local models:

- `qwen2.5:14b`
- `deepseek-r1:14b`
- `qwen2.5-coder:latest`
- `llama3.2:latest`
- `phi4-mini`

### OpenRouter

Best use:

- provider abstraction
- fallback access to Claude or Gemini family models
- simplifying one-off experiments when a direct key is not available

Recommended when:

- the direct provider is missing
- you want one routing layer across several model families
- you are testing model variants without changing the company layout

### NemoCloud

Use only if you have a specific benchmarked reason.

Do not make it the default for this lab until it has proven value against Claude, Gemini, Codex, or Ollama in the actual Paperclip workflows.

## Recommended Default Split

If you want the simplest sane default on this Mac:

- `chief-of-staff` -> Claude Haiku
- `researcher` -> Gemini Flash
- `lab-engineer` -> Codex
- `content-strategist` -> Claude
- `career-strategist` -> Claude Sonnet
- `growth-operator` -> Gemini Flash
- `finance-analyst` -> Ollama `qwen2.5:14b`
- `archivist` -> Ollama `llama3.2:latest`

This keeps the expensive or memory-heavy models out of the always-on path.

## Fallback Rules

Use this fallback order:

1. preferred cloud model for the role
2. direct provider fallback of the same family
3. OpenRouter fallback
4. smaller Ollama model
5. `qwen3.5:27b` only for explicit heavyweight offline work

## What Not To Do

- do not run `qwen3.5:27b` as the default always-on agent on a 24 GB Mac
- do not use the lab for production secrets
- do not publish externally without explicit approval
- do not treat a wrapper label like `claude_local` as if it were a final provider decision

## Related Docs

- [Paperclip Local Company Usage Guide](paperclip-local-company-usage-guide.md)
- [Paperclip Operational Status](../paperclip-operational-status.md)
- [Paperclip Role and Policy Bootstrap](../paperclip-role-policy-bootstrap.md)
- [Paperclip Local Docker Lab](paperclip-local-docker-lab.md)
