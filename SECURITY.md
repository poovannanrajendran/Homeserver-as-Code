# Security Policy

## Reporting
If you find a security issue, open a private security advisory or contact the repository owner directly.

## Public Repository Rules
- Never commit real credentials.
- Never commit private hostnames, internal DNS zones, or real LAN IP plans.
- Never commit production backup archives.

## Secrets Handling
- Keep secrets in private `.env` files ignored by Git.
- Use `.env.example` templates with `CHANGE_ME` placeholders.
- Rotate credentials after initial bootstrap and after any accidental exposure.
