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
Interactive host keys stay in 1Password. Mini backup containers intentionally use a separate exported backup key; see the Mini safety documentation before applying that target. Git signing uses `op-ssh-sign` on Mac; Git transport
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

## Alfred and input settings

Alfred's global activation shortcut remains a deliberate UI setting: open Alfred Preferences → General → Alfred Hotkey and record **Command–Space**. The repository disables Spotlight's corresponding shortcuts, but does not write undocumented Alfred preference keys. Save work and log out/in if macOS retains an old shortcut or trackpad configuration. Test internal and external three-finger dragging after login.

For Ghostty's existing workflow, open Alfred Preferences → Workflows, double-click its Hotkey trigger and record **Command–Escape**. Keep its Launch Apps & Files action pointing to Ghostty with Toggle visibility enabled. The inspected workflow previously used Option–Escape. Option–Command–Escape is macOS Force Quit; no saved Command–Escape owner was found, but another running app could still register it. If Alfred rejects it, inspect the exact conflict message rather than disabling unrelated shortcuts.

## Explicit Alfred site refresh

Activation initializes a public site list only when no file exists; it never invokes 1Password and preserves existing sites. To deliberately replace the list with current public entries:

```bash
alfred-sites-refresh --personal
```

For work sites, first opt in in the desired machine's Home Manager configuration:

```nix
programs.alfredWebsiteHelper.enableWorkSites = true;
# Override workAccount if needed; default is "my.1password.eu".
```

After applying that reviewed configuration, run `alfred-sites-refresh --work` yourself. This explicit action can request 1Password authorization and has a bounded wait. Output is written atomically with mode 600; failed fetches/invalid data preserve the prior file. The CLI does not print vault contents. Public-site updates also require an explicit refresh after the first initialization, so rebuilding never silently discards previously fetched work entries.

## Read-only completion check

Run `bash ~/dev/dotnix/scripts/dotnix-doctor.sh --machine macbook` (choose the actual target). Add `--plan` to compare desired output, available build, active-system link, and declared/installed casks. Socket presence is not authentication; an installed app is not proof it launches; a current-system link is not proof every activation step completed. The doctor never accesses a vault, tests remote SSH, or deletes apps.
