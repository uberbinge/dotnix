# 📱 Post-Setup App Configuration

After the bootstrap script completes, you'll need to manually configure a few essential applications. This guide covers only the apps that require manual setup.

## 🔐 Essential Security (5 minutes) meh

### **1Password**
```bash
open "/Applications/1Password 7 - Password Manager.app"
```
1. **Sign in** to your 1Password account
2. **Enable SSH agent**: Settings → Developer → Use SSH agent ✅
3. **Install browser extensions** in Chrome/Firefox/Safari

### **Tailscale VPN**
```bash
tailscale login    # Opens browser for authentication
tailscale status   # Verify connection
```

## 💻 Development Tools (5 minutes)

### **Shell History (Atuin)**
Set up sync for seamless history across machines:
```bash
atuin register    # Or: atuin login (if you have an account)
atuin sync        # Download your history
atuin stats       # Verify it worked
# Press Ctrl+R to test search
```

### **GitHub CLI**
```bash
gh auth login     # Authenticate with GitHub
gh auth status    # Verify authentication
```

### **AWS Tools** 
```bash
aws configure sso    # Set up AWS SSO (if using)
# Or: aws configure (for traditional credentials)
```

## 🎯 Productivity Apps (10 minutes)

### **Alfred**
Most complex setup, but worth it:

1. **Launch**: `open "/Applications/Alfred 5.app"`
2. **License**: Enter your license key (from 1Password)
3. **Hotkey**: Set to Cmd+Space (replaces Spotlight)
4. **Workflows**: Import your saved workflows or download new ones

**Essential Workflows:**
- Web searches (Google, Stack Overflow, GitHub)
- System control (kill processes, sleep, restart)
- Clipboard manager (built-in feature)

### **Browsers**
For each browser you use:
1. **Sign in** to sync bookmarks/extensions
2. **Install 1Password extension**
3. **Install uBlock Origin** (ad blocker)

## 🧪 Optional Setup

### **Development Apps**
- **Docker**: `open "/Applications/Docker.app"` → Wait for startup
- **JetBrains Toolbox**: Sign in → Install IDEs you need
- **VS Code**: Sign in for Settings Sync

### **Communication Apps**
All should auto-install via Homebrew - just sign in:
- **Slack**: Sign in to workspaces
- **Discord**: Sign in to account  
- **Telegram**: Sign in with phone number

### **Media & Design**
- **Spotify**: Sign in to account
- **Figma**: Sign in for design work

## ✅ Verification Checklist

After setup, verify everything works:

```bash
# Development environment
tmux-sessionizer    # Ctrl+X should open project selector
atuin stats         # Should show your command history  
gh auth status      # GitHub CLI authenticated
aws --version       # AWS CLI ready
node --version      # Node.js ready

# Test key features
hs                  # Should rebuild system (alias works)
z <project-name>    # zoxide navigation works
bat README.md       # Modern cat replacement works
```

### **Manual Verification:**
- [ ] **1Password**: Can access passwords, SSH agent working
- [ ] **Alfred**: Cmd+Space opens Alfred, basic searches work
- [ ] **Tailscale**: Connected to your network
- [ ] **Browsers**: Can access bookmarks, extensions installed
- [ ] **Terminal**: Ctrl+R searches history, Ctrl+X opens projects

## 💡 Tips & Tricks

### **Alfred Power User**
- **Clipboard History**: Space → Type 'clipboard' → Enable
- **Web Searches**: Add custom searches for your frequently used sites
- **File Navigation**: Use 'find' and 'open' commands

### **Shell Productivity** 
- **Project Navigation**: Use `z <partial-name>` instead of `cd`
- **History Search**: Ctrl+R is much more powerful with Atuin
- **Quick Rebuild**: `hs` rebuilds your entire system configuration

### **Development Workflow**
- **tmux-sessionizer**: Ctrl+X instantly switches between projects
- **GitHub CLI**: `gh repo clone`, `gh pr create`, `gh issue list`
- **AWS SSO**: Use `aws sso login` to refresh credentials

## 🆘 Common Issues

**"Command not found" errors**
```bash
# Reload your shell environment
source ~/.zshrc
# Or restart your terminal
```

**1Password SSH agent not working**
```bash
# Check if it's enabled
ssh-add -l
# Should show your 1Password keys
```

**Alfred not responding to Cmd+Space**
- Check System Preferences → Keyboard → Shortcuts → Spotlight
- Disable Spotlight's Cmd+Space, enable Alfred's

**Atuin not syncing**
```bash
atuin login      # Re-authenticate
atuin sync       # Force sync
```

---

**🎉 That's it!** Your development environment is now fully configured. The manual setup above should take about 20 minutes total, and you'll have a completely personalized, powerful development machine.
