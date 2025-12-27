# Post-Setup Configuration

After bootstrap completes, configure these apps manually.

## 1Password (Required)

1. Sign in to your account
2. Enable SSH agent: **Settings → Developer → Use SSH agent**
3. Install browser extensions

## Shell History (Atuin)

```bash
atuin register  # or: atuin login
atuin sync
```

## GitHub CLI

```bash
gh auth login
```

## Verification

```bash
ssh-add -l              # Should show 1Password keys
gh auth status          # GitHub authenticated
```

## Mac Mini Services

After rebuilding, start services:
```bash
jellyfin-start
immich-start
paperless-start
ha-start
borgmatic-start

docker ps  # Verify all running
```
