# Vercel Agent Skills for Codex

This repository now has the Vercel agent skill bundle installed for Codex-compatible workflows.

## What was installed

Installed globally in the Codex skill store:
- `vercel-composition-patterns`
- `deploy-to-vercel`
- `vercel-react-best-practices`
- `vercel-react-native-skills`
- `vercel-react-view-transitions`
- `vercel-cli-with-tokens`
- `web-design-guidelines`

## Why this matters

The Vercel plugin docs currently target Claude Code and Cursor first. The Codex-compatible path is the Vercel agent skills bundle, which gives the same practical workflow support for:
- linking and deploying Vercel projects
- token-based Vercel CLI usage
- Vercel-specific app patterns and deployment guidance

## Current auth model

Preferred:
- `VERCEL_TOKEN`
- optional `VERCEL_ORG_ID`
- optional `VERCEL_PROJECT_ID`

That lets the CLI work non-interactively without relying on browser login state.

## What this does not do

This does not automatically grant access to your Vercel account or project data.
To inspect live Vercel usage or deployments from the CLI, the environment still needs a valid token or logged-in Vercel context.

## Practical use in this repo

Use the installed skills when:
- deploying a project to Vercel
- checking project linkage
- managing preview deployments
- configuring Vercel CLI access with tokens

## Notes

- The external Vercel HTTP uptime probes were removed from this repo’s observability stack to avoid burning Edge Request quota.
- This document is the local reference for the Codex-side Vercel setup.
