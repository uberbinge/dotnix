#!/usr/bin/env bash
set -e

echo "🔐 Syncing config files from 1Password..."

# Check if 1Password CLI is available
if ! command -v op >/dev/null 2>&1; then
    echo "❌ 1Password CLI not found"
    exit 1
fi

# Test access to 1Password
if ! op --account=my.1password.eu vault list >/dev/null 2>&1; then
    echo "❌ Cannot access 1Password family account"
    echo "Make sure 1Password CLI integration is enabled in 1Password app"
    exit 1
fi

echo "✅ 1Password CLI access confirmed"

# AWS config
echo "📄 Setting up AWS config..."
if op --account=my.1password.eu read "op://Private/aws-config/notesPlain" > /tmp/aws-config 2>/dev/null; then
    mkdir -p "$HOME/.aws"
    cp /tmp/aws-config "$HOME/.aws/config"
    rm -f /tmp/aws-config
    chmod 600 "$HOME/.aws/config"
    echo "  ✅ ~/.aws/config"
else
    echo "  ❌ Failed to fetch AWS config"
fi

# AWS SSO config
echo "📄 Setting up AWS SSO config..."
if op --account=my.1password.eu read "op://Private/aws-sso-config/notesPlain" > /tmp/aws-sso-config 2>/dev/null; then
    mkdir -p "$HOME/.config/aws-sso"
    cp /tmp/aws-sso-config "$HOME/.config/aws-sso/config.yaml"
    rm -f /tmp/aws-sso-config
    chmod 600 "$HOME/.config/aws-sso/config.yaml"
    echo "  ✅ ~/.config/aws-sso/config.yaml"
else
    echo "  ❌ Failed to fetch AWS SSO config"
fi

# NPM config
echo "📄 Setting up NPM config..."
if op --account=my.1password.eu read "op://Private/npm-config/notesPlain" > /tmp/npmrc 2>/dev/null; then
    cp /tmp/npmrc "$HOME/.npmrc"
    rm -f /tmp/npmrc
    chmod 600 "$HOME/.npmrc"
    echo "  ✅ ~/.npmrc"
else
    echo "  ❌ Failed to fetch NPM config"
fi

# Gradle properties
echo "📄 Setting up Gradle properties..."
if op --account=my.1password.eu read "op://Private/gradle-properties/notesPlain" > /tmp/gradle.properties 2>/dev/null; then
    mkdir -p "$HOME/.gradle"
    cp /tmp/gradle.properties "$HOME/.gradle/gradle.properties"
    rm -f /tmp/gradle.properties
    chmod 600 "$HOME/.gradle/gradle.properties"
    echo "  ✅ ~/.gradle/gradle.properties"
else
    echo "  ❌ Failed to fetch Gradle properties"
fi

echo ""
echo "🎉 Config file sync completed!"
echo ""
echo "📋 Files synced:"
echo "  • AWS CLI config (for aws commands)"
echo "  • AWS SSO config (for aws-sso tool)"  
echo "  • NPM config (for private registry access)"
echo "  • Gradle properties (for Maven/JFrog access)"