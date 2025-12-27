# Media Setup Review - Recommendations & Future Improvements

## Completed Improvements

### 1. ✅ Eliminated Code Duplication (14% reduction)
- **Before**: 1299 lines total
- **After**: 1122 lines total (177 lines saved)
- Created shared `lib.nix` with reusable functions
- Services reduced by 35-48% each

### 2. ✅ Standardized Patterns
- Consistent Docker Compose script generation
- Uniform launchd service configuration
- DRY 1Password secret fetching
- Predictable command naming (`<service>-<action>`)

### 3. ✅ Simplified Management Scripts
- `media-server` now delegates to individual service commands
- `backup` is a thin wrapper over `borgmatic-*` commands
- Removed duplicate 1Password integration logic
- Better separation of concerns

### 4. ✅ Improved Maintainability
- New services can be added in ~30 lines (vs ~170 previously)
- Changes to patterns only need updating in one place (`lib.nix`)
- Comprehensive README documentation added

## Additional Recommendations

### High Priority

#### 1. Consider Environment Variables for Configuration

Currently hardcoded:
```nix
mediaVolume = "/Volumes/4tb";
userId = "501";
groupId = "20";
```

**Suggestion**: Make these configurable at the flake level:
```nix
# In flake.nix, pass to mini configuration:
extraHomeModules = [ 
  ./darwin/mini
  { 
    mini.mediaVolume = "/Volumes/4tb";
    mini.userId = "501";
    mini.groupId = "20";
  }
];
```

**Why**: Makes the config more portable if you get a new Mini or change volume names.

#### 2. Add Health Check Script

Create a unified health check command:
```bash
media-server health
```

That checks:
- Are all services running?
- Are they responding to health checks?
- Is the external volume mounted?
- Is there sufficient disk space?
- Is 1Password CLI authenticated?

**Implementation**: Add to `scripts.nix`

### Medium Priority

#### 3. Extract Common Docker Compose Patterns

The services share common patterns:
- Health checks
- Restart policies
- Volume patterns
- Timezone settings

**Suggestion**: Create Docker Compose fragment helpers in `lib.nix`:
```nix
mkHealthCheck = { endpoint, interval ? "30s" }: {
  test = "curl -f http://localhost${endpoint} || exit 1";
  inherit interval;
  timeout = "10s";
  retries = 3;
};

mkVolumeMount = { hostPath, containerPath, readonly ? false }:
  "${hostPath}:${containerPath}${if readonly then ":ro" else ""}";
```

#### 4. Add Monitoring/Alerting Hooks

Consider adding:
- Backup success/failure notifications (e.g., via ntfy.sh or Pushover)
- Service health monitoring
- Disk space alerts

**Example in borgmatic.nix**:
```nix
on_error:
  - echo "Backup failed" | ntfy pub my-topic
```

#### 5. Add Update Notification System

Create a script that checks for updates to all services:
```bash
media-server check-updates
```

Shows which Docker images have newer versions available.

#### 6. Centralize Timezone Configuration

Currently hardcoded in each service. Consider:
```nix
# In lib.nix:
timezone = "Europe/Berlin";

# Then use in services:
environment:
  - TZ=${miniLib.timezone}
```

### Low Priority

#### 7. Consider NixOS Modules Pattern

If you find yourself with more machines, consider converting to proper NixOS modules with options:

```nix
# darwin/mini/options.nix
{ lib, ... }:
{
  options.mini = {
    services.immich.enable = lib.mkEnableOption "Immich photo management";
    services.jellyfin.enable = lib.mkEnableOption "Jellyfin media server";
    # etc.
  };
}
```

**When**: Only if you have 3+ machines with similar needs

#### 8. Add Disaster Recovery Documentation

Document the complete recovery process:
1. Fresh Mac Mini setup
2. Restore from Borg backups
3. Recreate 1Password items
4. DNS configuration

**Where**: Add to `POST-SETUP-APPS.md` or separate `DISASTER-RECOVERY.md`

#### 9. Add Integration Tests

Create a `darwin/mini/tests.nix` that verifies:
- All scripts compile
- Docker Compose files are valid YAML
- 1Password paths are correct (without exposing secrets)

**Implementation**: Use Nix checks

## Potential Issues to Watch

### 1. Docker Symlink Copying in Borgmatic

The `borgmatic-start` script copies symlinks to real files because Docker can't follow Nix store symlinks:

```bash
for f in Dockerfile crontab docker-compose.yml; do
  if [ -L "$f" ]; then
    cp -L "$f" "$f.tmp" && rm "$f" && mv "$f.tmp" "$f"
  fi
done
```

**Why this matters**: This is a workaround. If you forget to run `borgmatic-start` after a rebuild, you'll use old configs.

**Better solution**: Use `home.file."...".force = true` and `text` instead of symlinks, which is already done. The copying might be legacy code that can be removed.

**Action**: Test if the copying is still necessary, remove if not.

### 2. Service Start Order Dependencies

Services start in parallel via launchd. If there are dependencies (e.g., Caddy depends on services being up), this could cause issues.

**Current state**: Seems okay - Caddy handles services being down gracefully

**If issues arise**: Add `StartInterval` to launchd configs to stagger starts

### 3. Secrets Cleanup

When services stop individually, their `.env` files aren't cleaned up (only when using `media-server stop`).

**Consideration**: This is probably fine - the files are in .gitignore and only readable by the user.

**If concerned**: Add cleanup to each service's `-stop` script

## Performance Considerations

### Current Setup is Good For:
- Home server with 1-10 users
- Content consumption workloads
- Automated backups

### Watch Out For:
- **Backup performance**: Sequential backups (2 AM, 4 AM, 5 AM) could take hours if data grows
  - **Solution**: Consider parallel backups or faster schedule
- **Immich ML**: Machine learning container can be CPU-intensive
  - **Solution**: Consider GPU acceleration if available
- **Jellyfin transcoding**: CPU transcoding can be slow
  - **Solution**: Consider hardware acceleration via VideoToolbox

## Security Hardening (Optional)

Current setup is secure for home use. For additional hardening:

1. **Network isolation**: Put media services on separate Docker network
2. **Fail2ban**: Add to Caddy for brute force protection
3. **Backup encryption verification**: Add periodic restore tests
4. **Secret rotation**: Document process for rotating 1Password secrets
5. **Audit logging**: Add logging for service starts/stops

## Summary

The refactoring achieved the main goals:
- ✅ Eliminated significant code duplication
- ✅ Created consistent patterns across services
- ✅ Made it easier to add new services
- ✅ Improved maintainability
- ✅ Switched to modern `docker compose` command

Most recommendations above are optional enhancements. The current implementation is clean, well-structured, and production-ready for a home media server.

**Highest value next steps**:
1. Add health check command
2. Add backup success/failure notifications
3. Extract common Docker Compose patterns
4. Centralize timezone configuration

Everything else can be done as-needed when requirements change.
