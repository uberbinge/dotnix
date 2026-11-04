{ pkgs, lib, username, ... }:
{
  home.homeDirectory = "/Users/${username}";

  # Brew sqlite is keg-only because macOS provides sqlite3. Keep one visible
  # sqlite3 owner in the Home Manager profile without a special Brew PATH.
  home.packages = [ pkgs.sqlite ];

  # Agent keys only by default; add explicit host exceptions via settings.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
      IdentityFile = "none";
      IdentitiesOnly = false;
      PreferredAuthentications = "publickey";
    };
  };

  # macOS-specific shell configuration
  programs.zsh.initContent = lib.mkAfter ''
    # 1Password SSH Agent override (macOS sets SSH_AUTH_SOCK by default)
    export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

    telegram() {
      local bot_token chat_id api_url
      bot_token=$(op read "op://Automation/telegram-bot/notesPlain" 2>/dev/null)
      chat_id=$(op read "op://Automation/telegram-chat-id/notesPlain" 2>/dev/null)
      if [[ -z "$bot_token" || -z "$chat_id" ]]; then
        echo "❌ Failed to read Telegram credentials from 1Password"
        return 1
      fi
      api_url="https://api.telegram.org/bot''${bot_token}/sendMessage"
      printf 'url = "%s"\n' "$api_url" | \
        curl -q --silent --show-error --config - --request POST \
          --data-urlencode "chat_id=''${chat_id}" \
          --data-urlencode "text=''${1:-}"
    }

    toDiscordTest() {
      local webhook payload
      webhook=$(op read "op://Automation/discord-test-webhook/notesPlain" 2>/dev/null)
      if [[ -z "$webhook" ]]; then
        echo "❌ Failed to read Discord webhook from 1Password"
        return 1
      fi
      payload=$(jq -n --arg content "''${1:-}" '{content: $content}')
      printf 'url = "%s"\n' "$webhook" | \
        curl -q --silent --show-error --config - \
          --header "Content-Type: application/json" \
          --request POST \
          --data "$payload"
    }
  '';

  # macOS-specific shell aliases
  programs.zsh.shellAliases = {
    unset-aws = "unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE";
  };

  imports = [
    ./alfred.nix
  ];

  # Homebrew owns Neovim; Home Manager supplies only its small plugin setup.
  home.file.".local/share/nvim/site/pack/dotnix/start/plenary.nvim".source = pkgs.vimPlugins.plenary-nvim;
  home.file.".local/share/nvim/site/pack/dotnix/start/telescope.nvim".source = pkgs.vimPlugins.telescope-nvim;
  home.file.".config/nvim/init.lua".text = ''
    vim.g.mapleader = ' '

    vim.cmd.packadd('plenary.nvim')
    vim.cmd.packadd('telescope.nvim')
    require('telescope').setup()

    local builtin = require('telescope.builtin')
    vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = 'Search files' })
    vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = 'Search by grep' })
    vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = 'Search buffers' })
    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = 'Search help' })
  '';

  # Package manager security: minimum release age (macOS-specific path)
  home.file."Library/Preferences/pnpm/rc".text = ''
    minimum-release-age=10080
  '';

  # Ghostty terminal configuration (installed via Homebrew)
  home.file.".config/ghostty/config".text = ''
    # Dark theme only
    theme = dark:Espresso,light:Gruvbox Material Light

    # Font configuration
    font-family = Roboto Mono
    font-size = 14

    # Save window state and layouts
    window-save-state = always

    # Native macOS titlebar
    macos-titlebar-style = native

    # Key bindings
    keybind = shift+enter=text:\n
  '';

  home.activation = {
    # Install Ghostty terminfo for SSH sessions
    installGhosttyTerminfo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      GHOSTTY_TERMINFO="/Applications/Ghostty.app/Contents/Resources/terminfo"
      if [ -d "$GHOSTTY_TERMINFO" ]; then
        verboseEcho "Installing Ghostty terminfo..."
        run mkdir -p "$HOME/.terminfo"
        run cp -R "$GHOSTTY_TERMINFO"/. "$HOME/.terminfo/"
      fi
    '';
  };
}
