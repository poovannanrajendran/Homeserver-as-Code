# OpenClaw Discord Handoff

Last updated: 2026-05-07

This document captures the live Discord setup for OpenClaw on `ai-node-01` so the channel can be re-established or verified without re-discovering the full sequence.

## Current State

- Host: `ai-node-01` (`192.168.1.24`)
- OpenClaw runtime: `2026.5.3`
- Gateway mode: `local`
- Gateway auth: `token`
- Discord plugin: `@openclaw/discord`
- Discord bot: `@OpenClaw_D`
- Discord guild: `1490345277020704789`
- Discord test channel: `#openclaw_d` (`1500957397512880349`)
- Allowlisted user: `841706877473914931`
- Route binding: `#openclaw_d` -> `fury`

## Secret Handling

- Discord bot token is stored outside the repository.
- Use `~/.env` on `ai-node-01` with `DISCORD_BOT_TOKEN=...`.
- Do not paste the token into chat or commit it to git.
- If the token was exposed, rotate it in Discord Developer Portal before reusing the setup.

## Live Config Shape

Relevant config entries in `~/.openclaw/openclaw.json`:

```json
{
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "..."
    }
  },
  "channels": {
    "discord": {
      "enabled": true,
      "groupPolicy": "allowlist",
      "token": {
        "source": "env",
        "provider": "default",
        "id": "DISCORD_BOT_TOKEN"
      },
      "guilds": {
        "1490345277020704789": {
          "requireMention": true,
          "users": [
            "841706877473914931"
          ]
        }
      }
    }
  },
  "bindings": [
    {
      "agentId": "fury",
      "match": {
        "channel": "discord",
        "guildId": "1490345277020704789",
        "peer": {
          "kind": "channel",
          "id": "1500957397512880349"
        }
      }
    }
  ]
}
```

## Bring-Up Sequence

Run this on `ai-node-01` in a shell where `~/.env` is loaded:

```bash
set -a
. ~/.env
set +a
sudo kill "$(sudo lsof -t -iTCP:18789 -sTCP:LISTEN 2>/dev/null | head -1)" 2>/dev/null || true
openclaw gateway
openclaw channels status --probe
openclaw channels list
```

If the gateway is already running and `openclaw gateway` refuses to start, kill the current listener on `127.0.0.1:18789` and start again.

## Validation

Use this in Discord:

```text
@OpenClaw_D reply with exactly: ready
```

Expected result:
- Discord shows the bot typing.
- The bot replies in `#openclaw_d`.
- The `fury` binding is exercised.

Useful follow-up checks:

```bash
openclaw channels logs --channel discord | tail -80
openclaw channels status --probe --deep
openclaw channels resolve --channel discord '#openclaw_d' --json
```

## Troubleshooting

- `secret unavailable in this command path` usually means `DISCORD_BOT_TOKEN` is not exported in the shell that starts the gateway.
- `EADDRINUSE` on `127.0.0.1:18789` means an older gateway process is still running.
- `agents: (none)` in Discord usually means the top-level `bindings[]` route is missing or stale.
- `origin not allowed` in the gateway log is usually the tailnet Control UI and does not block Discord.
- `plugins.allow is empty` is a warning, not the Discord failure here.

## Related Docs

- [Architecture](architecture.md)
- [Operations Runbook](runbooks.md)
- [OpenClaw Memory and Second Brain Plan](openclaw-memory-secondbrain-plan.md)
