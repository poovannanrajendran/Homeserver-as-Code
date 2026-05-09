# Paperclip Local Company Usage Guide

This guide gives the practical workflow for using the local Paperclip company on the Mac lab.

## What This Company Is For

Use `Poovi Paper Company` for:

- role and workflow prototyping
- private prompt testing
- local agent strategy experiments
- grounding-pack backed drafting
- model/provider evaluation
- safe rehearsal before promoting anything to the production runner

## What It Is Not For

- production publishing without approval
- storing secrets in chat
- heavy always-on reasoning on a 24 GB Mac
- using `qwen3.5:27b` as the default path

## Recommended Workflow

1. Start with the company dashboard.
2. Pick the agent by role, not by model size.
3. Keep the task small and specific.
4. Use the grounding pack for context.
5. Capture successful output back into a doc or note.
6. Promote only the parts that work repeatedly.

## Agent-by-Agent Testing Prompts

### `chief-of-staff`

Prompt:

> Review the local Paperclip company and give me the safest next test to run in one step.

Expected behaviour:

- concise plan
- clear prioritisation
- no unnecessary digression

### `researcher`

Prompt:

> Summarise the grounding pack into three points I should know before making any change.

Expected behaviour:

- concise synthesis
- source-aware summary
- no speculation

### `lab-engineer`

Prompt:

> Check the local Paperclip stack for obvious operational issues and give me the minimal fix list.

Expected behaviour:

- shell or stack-aware reasoning
- practical remediation steps
- no long essay

### `content-strategist`

Prompt:

> Draft a UK-English LinkedIn post from the grounding pack about one local lab lesson.

Expected behaviour:

- natural tone
- no clichés
- useful, specific content

### `career-strategist`

Prompt:

> Write a two-line professional positioning summary for Poovi using the local company context.

Expected behaviour:

- crisp positioning
- strong narrative
- no generic fluff

### `growth-operator`

Prompt:

> Give me five low-risk growth experiments I can run from the local Paperclip setup this week.

Expected behaviour:

- actionable ideas
- low friction
- clear first test

### `finance-analyst`

Prompt:

> Compare the cost and risk of using cloud models versus local Ollama for this Paperclip company.

Expected behaviour:

- trade-off analysis
- cost awareness
- practical recommendation

### `archivist`

Prompt:

> Turn the latest successful Paperclip test into a short record with date, outcome, and next step.

Expected behaviour:

- compact summary
- durable record
- easy to reuse later

## Model Choice Guidance

Use this rule of thumb:

- Claude for writing and orchestration
- Gemini for fast synthesis and ideation
- Codex for code and automation
- Ollama for local privacy and cheap repeatable work
- OpenRouter when you want provider flexibility

Do not use `qwen3.5:27b` unless the test really needs the larger context and you are prepared for the memory cost.

## Good Local Test Use Cases

Use these first:

1. Ask `chief-of-staff` for the next safe local change.
2. Ask `researcher` to compress the grounding pack into a test brief.
3. Ask `content-strategist` to draft one post from a local company note.
4. Ask `lab-engineer` to check the stack and produce a fix list.
5. Ask `archivist` to store the outcome of the best prompt.

## Bad Test Use Cases

Avoid these:

- long unconstrained brainstorming with no role
- full-company writes without a brief
- heavyweight reasoning on `qwen3.5:27b` as the default
- external publishing without approval

## Recommended First End-to-End Check

If you want one clean test, use this:

> `chief-of-staff`: inspect the local Paperclip company, pick the best next prompt to validate the writing path, and keep the answer under 8 bullets.

Why this one:

- it tests routing
- it tests prompt discipline
- it does not need a huge model
- it tells you the next action immediately

## Related Docs

- [Paperclip Local Company Handbook](paperclip-local-company-handbook.md)
- [Paperclip Operational Status](../paperclip-operational-status.md)
- [Paperclip Local Docker Lab](paperclip-local-docker-lab.md)
