{ pkgs, lib, username, githubUserEmail, githubUserName, specialArgs, ... }:
{
  imports = [
    ../common/scripts.nix
    ../common/nixvim.nix
    ../common/vcs.nix
  ];

  home = {
    stateVersion = "23.11";
    username = username;

    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      # Core utilities (not available as programs.*)
      gnumake
      coreutils
      gnused

      # Development tools
      lazygit
      delta
      fd
      yt-dlp
      rustup
      jsonnet
      ncspot
      deno

      # Container wrapper scripts using writeShellApplication
      (writeShellApplication {
        name = "podman";
        runtimeInputs = [ docker ];
        text = ''exec docker "$@"'';
      })

      (writeShellApplication {
        name = "podman-compose";
        runtimeInputs = [ docker-compose ];
        text = ''exec docker-compose "$@"'';
      })
    ];
    # Cache for tmux-sessionizer is built lazily on first use - no activation needed
  };

  programs.home-manager.enable = true;

  # Use programs.* modules instead of packages where available
  programs.bat.enable = true;
  programs.ripgrep.enable = true;
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
    };
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.jq.enable = true;

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd" "z" ];
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      dialect = "us";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      command_timeout = 1000;
      format = "$all";
      scan_timeout = 30;
      directory = {
        truncation_length = 3;
        disabled = false;
      };
      git_branch = {
        format = "[$branch]($style) ";
        disabled = false;
      };
      git_status.format = "([$all_status$ahead_behind]($style))";
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        disabled = false;
      };
      time = {
        disabled = false;
        format = "[$time]($style) ";
        time_format = "%H:%M:%S";
        style = "dimmed white";
      };
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    oh-my-zsh = {
      enable = true;
      theme = "";
    };
    autosuggestion = {
      enable = true;
      strategy = [ "history" ];
      highlight = "fg=244";
    };
    syntaxHighlighting.enable = true;
    initContent = lib.mkMerge [
      # Common shell initialization
      ''
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.amp/bin:$PATH"
        eval "$(mise activate zsh)"
        setopt AUTO_CD

        _tmux_sessionizer_widget() {
          local selected
          selected=$(tmux-sessionizer --print-only)
          if [[ -n "$selected" ]]; then
            BUFFER="tmux-sessionizer '$selected'"
            zle accept-line
          else
            zle reset-prompt
          fi
        }
        zle -N _tmux_sessionizer_widget
        bindkey '^F' _tmux_sessionizer_widget

        telegram() {
          local bot_token
          local chat_id
          bot_token=$(op read "op://Automation/telegram-bot/notesPlain" 2>/dev/null)
          chat_id=$(op read "op://Automation/telegram-chat-id/notesPlain" 2>/dev/null)
          if [[ -z "$bot_token" || -z "$chat_id" ]]; then
            echo "❌ Failed to read Telegram credentials from 1Password"
            return 1
          fi
          curl -s -X POST "https://api.telegram.org/bot''${bot_token}/sendMessage" \
            -d "chat_id=''${chat_id}" \
            -d "text=$1"
        }

        toDiscordTest() {
          local webhook
          local payload
          webhook=$(op read "op://Automation/discord-test-webhook/notesPlain" 2>/dev/null)
          if [[ -z "$webhook" ]]; then
            echo "❌ Failed to read Discord webhook from 1Password"
            return 1
          fi
          payload=$(jq -n --arg content "$1" '{content: $content}')
          curl -s -H "Content-Type: application/json" \
            -X POST \
            -d "$payload" \
            "$webhook"
        }
      ''
    ];

    shellAliases = lib.mkMerge [
      # Common aliases for all platforms
      {
        ".." = "cd ..";
        "..." = "cd ../..";
        ls = "eza";
        ll = "eza -al --icons";
        la = "eza -a";
        cat = "bat";
        g = "git";
        gst = "git status";
        ga = "git add";
        gc = "git commit";
        gco = "git checkout";
        gcm = "git checkout main";
        gcam = "git commit -am";
        gp = "git push";
        gl = "git pull";
        c = "clear";
        zshconfig = "nvim ~/.zshrc";
        ohmyzsh = "nvim ~/.config/oh-my-zsh";
        gw = "./gradlew";
        yi = "yarn install";
        nm = "nvim";
        vim = "nvim";
        v = "nvim";
        rzsh = "exec zsh";

        # Mise task shortcuts
        b = "mise run build";
        t = "mise run test";
        d = "mise run deploy-dev";
        f = "mise run format";

        # Additional shortcuts
        s = "gst";
        l = "lazygit";

        # Container aliases
        podman = "docker";
      }

      # Platform-specific hs alias using lib.mkIf
      # Uses username-based detection (matches bootstrap.sh logic)
      (lib.mkIf pkgs.stdenv.isDarwin {
        hs = "cd ~/dev/dotnix && sudo darwin-rebuild switch --flake .#$([[ $(whoami) == 'waqas' ]] && echo mini || echo work)";
      })

      (lib.mkIf pkgs.stdenv.isLinux {
        hs = "cd ~/dev/dotnix && sudo nixos-rebuild switch --flake .#nixos";
      })

      # Nix cleanup - delete generations older than 30 days
      {
        nix-cleanup = "sudo nix-collect-garbage --delete-older-than 30d";
      }
    ];
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--icons"
    ];
  };

  # Tmux configuration with vim-like keybindings and improved usability
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    mouse = true;
    plugins = with pkgs.tmuxPlugins; [ vim-tmux-navigator ];
    escapeTime = 0;
    historyLimit = 15000;
    newSession = true;
    extraConfig = ''
      # Change prefix from C-b to C-a (easier to reach)
      set -g prefix C-a
      unbind C-b
      bind-key C-a send-prefix

      # Better window splitting with more intuitive keys
      unbind %
      bind \\ split-window -h      # Split horizontally with \
      unbind '"'
      bind - split-window -v       # Split vertically with -

      # Reload tmux config with 'r'
      unbind r
      bind r source-file ~/.config/tmux/tmux.conf

      # Resize panes with vim-like keys (repeatable)
      bind -r j resize-pane -D 10  # Resize down
      bind -r k resize-pane -U 10  # Resize up
      bind -r l resize-pane -R 10  # Resize right
      bind -r h resize-pane -L 10  # Resize left
      bind -r m resize-pane -Z     # Toggle pane zoom

      # Window title and appearance settings
      set-option -g set-titles on
      set-option -g set-titles-string "#{session_name}"
      set-option -g clock-mode-style 12
      set -g status-right ""
      set -g status-style bg=default,fg=colour105

      # Vi mode for copy
      set -g mode-keys vi
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"

      # Mouse drag auto-copies to clipboard
      bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe-and-cancel "pbcopy"
      set -s focus-event on        # Enable focus events for better integration with vim

      # Sessionizer - Ctrl+f directly (no prefix needed)
      bind -n C-f run-shell "tmux neww tmux-sessionizer"
    '';
  };

  # Configure IdeaVim for JetBrains IDEs
  home.file.".ideavimrc".text = ''
    "" Source your .vimrc
    "source ~/.vimrc

    "" -- Suggested options --
    " Show a few lines of context around the cursor. Note that this makes the
    " text scroll if you mouse-click near the start or end of the window.
    set scrolloff=5

    " Do incremental searching.
    set incsearch

    " Don't use Ex mode, use Q for formatting.
    map Q gq


    "" -- Map IDE actions to IdeaVim -- https://jb.gg/abva4t
    "" Map \r to the Reformat Code action
    "map \r <Action>(ReformatCode)

    "" Map <leader>d to start debug
    "map <leader>d <Action>(Debug)

    "" Map \b to toggle the breakpoint on the current line
    "map \b <Action>(ToggleLineBreakpoint)


    " Find more examples here: https://jb.gg/share-ideavimrc
  '';
}
