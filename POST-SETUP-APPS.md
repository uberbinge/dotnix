# Post-Setup Configuration

After bootstrap completes, configure these apps manually.

## 1Password (Required)

1. Sign in to your account
2. Enable SSH agent: **Settings → Developer → Use SSH agent**
3. Install browser extensions

## SSH and Git on Mac

Home Manager manages `~/.ssh/config`. SSH uses the 1Password agent for all hosts,
with `IdentityFile none`, `IdentitiesOnly no`, and public-key authentication only.
Default local private-key files are not loaded. Explicit command-line identity
options or host-specific settings can override this policy.

Enable and unlock the 1Password SSH agent, and make the desired existing keys
available to it. Register the public key with GitHub for authentication; register
it separately as a signing key if you want GitHub to verify signed commits.
Private keys stay in 1Password. Git signing uses `op-ssh-sign` on Mac; Git transport
uses SSH only for SSH remotes (for example `git@github.com:uberbinge/dotnix.git`).

On first activation, the configured Home Manager backup extension preserves an
existing unmanaged SSH config as `~/.ssh/config.backup`. Review any existing host
rules and port them to `programs.ssh.settings` before activation. Never force
replacement of an unknown config or overwrite a pre-existing backup; Home Manager
will stop on a backup collision. No private-key files need moving or deleting.

For a password-only server, add an explicit host exception in a Darwin Home
Manager module (replace the example hostname with the intended server):

```nix
programs.ssh.settings."legacy.example.org" = {
  PreferredAuthentications = "keyboard-interactive,password";
  PubkeyAuthentication = false;
  PasswordAuthentication = true;
  KbdInteractiveAuthentication = true;
};
```

Home Manager renders host-specific settings before `Host *`, so this exception
applies only to the named server. Inspect effective settings without connecting:

```bash
ssh -G git@github.com
ssh -G legacy.example.org
```

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
