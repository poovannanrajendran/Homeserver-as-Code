---
name: Poovi Paper Company
slug: poovi-papercompany
description: Local Paperclip lab company for testing Poovi's personal AI operating model before promoting patterns to production.
schema: agentcompanies/v1
version: 0.1.0
brandColor: "#0f766e"
authors:
  - name: Poovannan Rajendran (Poovi)
goals:
  - Test Paperclip companies, agents, MCP routing, model routing, and artefacts safely in Docker.
  - Convert Poovi's grounding pack into reusable agent context without copying secrets into the lab image.
  - Prototype career, content, homelab, and finance workflows before promoting them to the production runner.
  - Keep all external publishing and destructive infrastructure changes behind explicit approval.
includes:
  - agents/chief-of-staff/AGENTS.md
  - agents/researcher/AGENTS.md
  - agents/lab-engineer/AGENTS.md
  - agents/content-strategist/AGENTS.md
  - agents/career-strategist/AGENTS.md
  - agents/growth-operator/AGENTS.md
  - agents/finance-analyst/AGENTS.md
  - agents/archivist/AGENTS.md
  - skills/poovi-grounding-pack/SKILL.md
  - skills/local-lab-safety/SKILL.md
  - skills/uk-english-brand-voice/SKILL.md
  - skills/insurance-ai-product-thinking/SKILL.md
  - tasks/daily-brief/TASK.md
  - tasks/weekly-lab-review/TASK.md
  - tasks/content-repurposing/TASK.md
  - tasks/career-market-scan/TASK.md
---

# Poovi Paper Company

This is the local Docker-only Paperclip company for Poovi's personal AI lab.

It is intentionally separate from:

- Production Paperclip on `automation-runner-01`
- FinOSafe Media Group
- OpenClaw live Telegram/Discord channels
- Live publishing workflows

## Grounding

The company uses the read-only grounding pack mounted at:

`/grounding/Poovi_GroundingPack`

Agents should start with:

1. `/grounding/Poovi_GroundingPack/00_INDEX.md`
2. `/grounding/Poovi_GroundingPack/01_profile.md`
3. Task-specific files from the index

## Operating Rules

- Use UK English.
- Treat the lab as disposable.
- Do not publish externally without explicit approval.
- Do not write to mounted grounding-pack files.
- Do not use production secrets in experiments.
- Prefer local/dummy MCP tools before remote n8n tools.
