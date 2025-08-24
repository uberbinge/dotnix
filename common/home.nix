{ pkgs, lib, username, githubUserEmail, githubUserName, specialArgs, ... }:{
  imports = [
    ../common/scripts.nix
    ../common/nixvim.nix
    ../common/packages.nix
    ../common/vcs.nix
  ];
  home = {
  stateVersion = "23.11";
      username = username;
      sessionVariables = {
        EDITOR = "nvim";
        # API Keys from 1Password (family account)
        TELEGRAM_BOT = "op://Private/telegram-bot/notesPlain";
        TELEGRAM_CHAT_ID = "op://Private/telegram-chat-id/notesPlain";
        BRAVE_API_KEY = "op://Private/brave-api-key/notesPlain"; 
        TEST_USER = "op://Private/test-user/notesPlain";
      };
      packages = with pkgs; [
        # Additional packages specific to this configuration
        atuin
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
      export PATH="$HOME/.local/bin:$HOME/.claude/local:$PATH"
      eval "$(mise activate zsh)"
      setopt AUTO_CD
      # 1Password SSH Agent override (macOS sets SSH_AUTH_SOCK by default)
      if [[ "$(uname)" == "Darwin" ]]; then
        export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
      fi
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
        curl -s -X POST https://api.telegram.org/bot$TELEGRAM_BOT/sendMessage \
                        -d chat_id=$TELEGRAM_CHAT_ID \
                        -d text="$1"
        }
        
      # Cross-platform home switch function
      hs() {
        cd ~/dev/dotnix
        export FLAKE_USERNAME=$(whoami)
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
          # macOS - use darwin-rebuild
          sudo -E darwin-rebuild switch --flake .#default
        elif command -v nixos-rebuild >/dev/null 2>&1; then
          # NixOS - use nixos-rebuild  
          sudo -E nixos-rebuild switch --flake .#nixos
        elif command -v home-manager >/dev/null 2>&1; then
          # Linux with home-manager only
          home-manager switch --flake .#"$FLAKE_USERNAME"
        else
          echo "❌ No supported Nix rebuild command found"
          echo "Available options:"
          echo "  - darwin-rebuild (macOS)"
          echo "  - nixos-rebuild (NixOS)" 
          echo "  - home-manager (Linux)"
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
      refrzsh = "exec zsh";
      cl4 = "aws-sso exec -p ai-coding.tools-ai-coding-maintainers -- claude --model eu.anthropic.claude-sonnet-4-20250514-v1:0";
      cl4d = "aws-sso exec -p ai-coding.tools-ai-coding-maintainers -- claude --dangerously-skip-permissions --model eu.anthropic.claude-sonnet-4-20250514-v1:0";
      cl = "aws-sso exec -p ai-coding.tools-ai-coding-maintainers -- claude";
      cld = "aws-sso exec -p ai-coding.tools-ai-coding-maintainers -- claude --dangerously-skip-permissions";
      unset-aws = "unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE";
      daily = "cd \"$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/\" && cl4 --continue";
      
      # Mise task shortcuts
      b = "mise run build";
      t = "mise run test";
      d = "mise run deploy-dev";
      f = "mise run format";
      
      # Additional shortcuts
      s = "gst";
      l = "lazygit";
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
