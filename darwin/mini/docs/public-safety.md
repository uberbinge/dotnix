# Public Safety Checklist

`dotnix` is a public repository. Keep it declarative, but do not commit runtime
state or secrets.

## Allowed In Public

- Nix modules and templates
- Local service ports
- Generic volume layout such as `/Volumes/4tb`
- 1Password item names, if those names are acceptable to disclose
- Public DNS names, if exposing the service names is acceptable

## Not Allowed In Public

- Private keys, exported Borg keys, API tokens, app passwords, or `.env` files
- Hetzner account IDs, repository passphrases, Telegram tokens, Cloudflare tokens
- Generated runtime files under `~/.config/media-server`
- Logs, databases, health data, photos, documents, or backup archives
- Real data from `/Volumes/*`

## Domain Names

The Mac Mini is intended to be reachable only over Tailscale. Service domains
are configured in `services.mediaServer.domains` so the public service names are
a deliberate choice in one place. See `network.md` for the network model.

Current defaults reveal these service names:

- `immich.ti.waqas.dev`
- `jelly.ti.waqas.dev`
- `paperless.ti.waqas.dev`
- `home.ti.waqas.dev`

If those names should not be public, override them with less descriptive names or
move the domain values into a private local module that is not committed.

## Quick Audit

Before pushing, inspect staged changes:

```bash
git diff --cached
```

Run the public-safety helper:

```bash
bash scripts/public-safety-check.sh
```

This script is only a guardrail. Review diffs manually before pushing.
