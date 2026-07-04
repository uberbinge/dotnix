# Network Model

The Mac Mini is intended to be reachable only through Tailscale. Public DNS
records may exist for convenience, but the services should not be exposed by
router port forwards or public firewall rules.

## Access Model

- Tailscale app is installed through Homebrew.
- Exit-node and Tailnet settings are operational state, not currently declared
  in Nix.
- Caddy terminates HTTPS locally and proxies to services on localhost.
- Cloudflare DNS is used for ACME DNS-01 challenges.
- Caddy's Cloudflare token is fetched from 1Password at runtime.

## Domain Names

Service domains are configured in one option set:

```nix
services.mediaServer.domains = {
  immich = "immich.ti.waqas.dev";
  jellyfin = "jelly.ti.waqas.dev";
  paperless = "paperless.ti.waqas.dev";
  homeAssistant = "home.ti.waqas.dev";
};
```

These values are used by Caddy, Paperless, and the Mac Mini Alfred shortcuts.

The defaults are public repository data and reveal service names. If that is not
acceptable, override them with less descriptive names or move the values into a
private, uncommitted module.

## Safety Checks

Before assuming a service is private, verify outside this repository:

- No router port forward points at the Mac Mini for these service ports.
- macOS firewall rules do not expose these services to untrusted networks.
- Tailscale ACLs allow only intended users/devices.
- DNS records do not imply public reachability without Tailscale.

Do not change live network exposure without an explicit rollout and rollback
plan.
