{ pkgs, lib, username, githubUserEmail, githubUserName, specialArgs, ... }:{
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
        # API Keys from 1Password (family account)
        # Note: op:// references don't auto-resolve in sessionVariables
        # Functions that need secrets fetch them directly using 'op read'
        BRAVE_API_KEY = "op://Private/brave-api-key/notesPlain";
        TEST_USER = "op://Private/test-user/notesPlain";
      };
      packages = with pkgs; [
        # Common packages for all systems
        gnumake
        git
        ripgrep

        # Additional packages specific to this configuration
        bat
        coreutils
        gh
        lazygit
        delta
        eza
        fd
        fzf
        gnused
        jq
        zoxide
        yt-dlp
        rustup
        jsonnet
        ncspot
        deno
        
        # Create podman -> docker wrapper script
        (writeShellScriptBin "podman" ''
          exec docker "$@"
        '')
        
        # Create podman-compose -> docker-compose wrapper script
        (writeShellScriptBin "podman-compose" ''
          exec docker-compose "$@"
        '')
      ];
      activation = {
        rebuildCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
          $DRY_RUN_CMD $HOME/.local/bin/update-find-cache.sh
        '';
      };
  };

  programs.home-manager.enable = true;

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
    syntaxHighlighting = {
      enable = true;
    };
    initContent = ''
      export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
      eval "$(mise activate zsh)"
      setopt AUTO_CD
      # 1Password SSH Agent configuration (platform-specific paths handled in platform configs)
      # Environment variables are now handled directly by Nix home.sessionVariables
      _tmux_sessionizer_widget() {
        tmux-sessionizer
        zle reset-prompt
      }
      zle -N _tmux_sessionizer_widget
      bindkey '^X' _tmux_sessionizer_widget
      # Auto-tmux disabled for Ghostty transition - allows Ghostty state restoration
      # if [[ -z "$TMUX" && -t 0 ]]; then
      #   if command -v tmux >/dev/null 2>&1; then
      #     tmux attach-session -t 0 2>/dev/null || tmux new-session
      #   fi
      # fi

      telegram() {
        local bot_token=$(op read "op://Private/telegram-bot/notesPlain" 2>/dev/null)
        local chat_id=$(op read "op://Private/telegram-chat-id/notesPlain" 2>/dev/null)
        if [[ -z "''$bot_token" || -z "''$chat_id" ]]; then
          echo "❌ Failed to read Telegram credentials from 1Password"
          return 1
        fi
        curl -s -X POST "https://api.telegram.org/bot''${bot_token}/sendMessage" \
                        -d "chat_id=''${chat_id}" \
                        -d "text=''$1"
        }

      toDiscordTest() {
        local webhook=$(op read "op://Private/discord-test-webhook/notesPlain" 2>/dev/null)
        if [[ -z "''$webhook" ]]; then
          echo "❌ Failed to read Discord webhook from 1Password"
          return 1
        fi
        local payload=$(jq -n --arg content "''$1" '{content: $content}')
        curl -s -H "Content-Type: application/json" \
             -X POST \
             -d "''$payload" \
             "''$webhook"
        }

      # Cross-platform home switch function (auto-detects machine)
      hs() {
        cd ~/dev/dotnix
        export FLAKE_USERNAME=$(whoami)
        local hostname=$(hostname -s)
        local flake_config="default"

        # Detect which flake config to use based on hostname
        if [[ "$hostname" == *"mini"* || "$hostname" == *"Mini"* ]]; then
          flake_config="mini"
        fi

        if [[ "$OSTYPE" == "darwin"* ]]; then
          sudo -E darwin-rebuild switch --flake .#"$flake_config"
        elif command -v nixos-rebuild >/dev/null 2>&1; then
          sudo -E nixos-rebuild switch --flake .#nixos
        elif command -v home-manager >/dev/null 2>&1; then
          home-manager switch --flake .#"$FLAKE_USERNAME"
        else
          echo "❌ No supported Nix rebuild command found"
          return 1
        fi
      }
    '';
    shellAliases = {
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
      # Platform-specific aliases moved to platform configs
      
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
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
    };
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
    keyMode = "vi";                # Use vi key bindings in copy mode
    mouse = true;                  # Enable mouse support
    plugins = with pkgs.tmuxPlugins; [ vim-tmux-navigator ];  # Seamless navigation between tmux and vim
    escapeTime = 0;                # Remove delay when pressing escape
    historyLimit = 15000;          # Increase scrollback buffer size
    newSession = true;             # Create a new session if one doesn't exist
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
      set -s focus-event on        # Enable focus events for better integration with vim
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
