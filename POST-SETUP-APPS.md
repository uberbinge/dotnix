# Post-Setup Configuration

Start after `hs` (or a reviewed `darwin-rebuild switch`). Bootstrap's plan and
build-only modes do not activate. Activation applies Homebrew apps and the Home
Manager target marker; mise runtimes and AI CLIs remain explicit installs.
After the Nix-to-Brew mise handoff, run `exec /bin/zsh -l` in the old terminal
to clear inherited hooks. `whence -p mise` should report
`/opt/homebrew/bin/mise`; old shims are excluded from the interactive PATH.

From `~/dev/dotnix`, verify the local target and then install runtimes
explicitly:

```bash
cd ~/dev/dotnix
bash scripts/local-target.sh    # Reads the target activated on this Mac
mise run runtimes:install       # Bun, Deno, Go, Node, and Rust
mise run doctor                 # Local read-only status
```

To install the Health Export query client on this Mac, keep the local
`~/dev/health-export/health-server` checkout and run:

```bash
mise run health:install-cli
```

This builds the Go program into `~/.local/bin/hk-cli` from source. It does not
query the health server, sync records, or install the Mini service. Dotnix sets
`HEALTH_SERVER_URL` for the client in Home Manager; make sure `~/.local/bin` is
on your `PATH` before using `hk-cli`. Repeat the task after updating the local
checkout. The health-export repository currently tracks private data, so it
must not be added as a Nix flake input or copied into the Nix store.

Choose only the AI CLIs you want on this Mac. These tasks need no host suffix
and do not sign in, start listeners, or enable the Herdr web UI:

```bash
mise run ai:install:claude-code
mise run ai:install:codex-cli
mise run ai:install:pi
mise run ai:install:herdr-web-ui # Requires the Brew Herdr app and mise runtimes
mise run ai:install:collie
```

Complete app sign-ins, permissions, and license prompts yourself.

For Handy, choose a transcription model and grant microphone and accessibility
access when prompted. Granola requires Google or Microsoft sign-in and prompts
for calendar, microphone, and system audio access. Review these prompts in each
app; installation alone does not grant them.

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

## GitHub CLI

```bash
gh auth login
```

## Verification

```bash
ssh-add -l              # Should show 1Password keys
gh auth status          # GitHub authenticated
whence -p mise          # /opt/homebrew/bin/mise on macOS
mise current            # Bun, Deno, Go, Node, and Rust match config/mise/global.toml
```

`mise doctor` is available for deeper diagnostics. It can report missing
leftover shims even when the active Brew binary and installed runtime paths
work; this is separate from the old shell function failure.

To change a shared runtime, edit `config/mise/global.toml`, review the diff,
apply with `hs`, and rerun `mise run runtimes:install`. Use `mise tasks ls` for
explicit AI update tasks; no post-install dispatcher runs them automatically.
Project runtimes and dependency locks belong in their project repositories.

## Touch ID for sudo

The Darwin configuration enables Touch ID and `pam_reattach`, including sudo
from persistent tmux sessions. After activation, start a new terminal session
and run `sudo -k && sudo true`; macOS should offer Touch ID. If it still asks for
a password, inspect `/etc/pam.d/sudo_local` before changing PAM settings.

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

`mise run doctor` reports local status. On macOS,
`bash scripts/dotnix-doctor.sh --machine "$(bash scripts/local-target.sh)" --plan`
adds a read-only build and cask comparison. Neither proves app launch,
authentication, or every activation step; the doctor does not access vaults,
test remote SSH, or delete apps.
