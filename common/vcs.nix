{ pkgs, lib, githubUserEmail, githubUserName, ... }:
{
  # Git configuration
  programs.git = {
    enable = true;
    userName = githubUserName;
    userEmail = githubUserEmail;
    ignores = [
      ".DS_Store"
      ".mise.toml"
      "# Claude Code settings"
      ".claude/settings.local.json"
    ];

    aliases = {
      unstage = "reset HEAD --";
      last = "log -1 HEAD";
      visual = "!gitk";
      gone = "! git fetch -p && git for-each-ref --format '%(refname:short) %(upstream:track)' | awk '$2 == \"[gone]\" {print $1}' | xargs -r git branch -D";
    };

    # Merge and diff settings
    extraConfig = {
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";

      # Git LFS configuration
      filter.lfs = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };

      # Colorful diff output for better readability
      color.diff = {
        meta = "yellow bold";
        frag = "magenta bold";
        old = "red bold";
        new = "green bold";
      };

      # Use delta for improved diff display
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";

      # Delta configuration for better diff visualization
      delta = {
        navigate = true;           # Enable navigation between diff sections
        light = false;             # Use dark mode
        features = "line-numbers decorations";
        syntax-theme = "Monokai Extended Bright";
      };

      # SSH signing configuration with 1Password
      # Use full SSH public key for signing (replace with your actual key from 1Password)
      user.signingkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCvxBgcSK/xqo38YHW6GWRBDcZyGZ2nZahlAKYMwNYiNv1vZmolbEv2N0BaPLX1mMWVToRt0Kr5PJIzzDHP765I4qFn7Go8H3H/kS2wDgJ4GaMgp6SpcHiFqwAIfRb54igC50AFbxx4ecCCjegCQppyKP2z5Ispcz/t+jN85ZEcTcQCR5Oio4Xjf/LF7FkEJAwCMsu4FMdTOQpH6vFKm5xYK2fz6+Tf/xdrjfifQEQD+yz+2nt4t9RmjRu9kSLfmAZqzAIlOR1mNlxDBZyoqdpPtvwkvfrLF0PJnMLXvrdQ2fa/LgUfFWTe4F5/qPJinHIDmDGtLXeH8Gj2FVpvAWYIiOGIPj/Zb3uP4bKordT4YfBtVPA33L9T3fu6WJBjemYR9VympPti2bM3OfphNzPYIM8LJo/Qdvd+bcya3YUNKChM/whVmrn3dymM6tyKO0P/v0IPopgj4tEM376TdXRyeVqn6BIozqQbu9Fw5EIWgtxl5JPIOc2xEOFI0/zg+ck=";
      gpg.format = "ssh";
      "gpg \"ssh\"".program = if pkgs.stdenv.isDarwin 
        then "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
        else "${pkgs._1password-gui}/bin/op-ssh-sign";
      commit.gpgsign = true;

      # Platform-specific credential helper
      credential = {
        helper = if pkgs.stdenv.isDarwin then "osxkeychain" else "cache --timeout=3600";
      };
    };
  };

  # Jujutsu (jj) VCS configuration
  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = githubUserName;
        email = githubUserEmail;
      };
      ui = {
        default-command = "log";
        diff-editor = "nvim";
        merge-editor = "nvim";
        pager = "delta";
      };
      git = {
        # Automatically create local bookmarks for Git branches
        auto-local-bookmark = true;
        # Push all branches, not just the current one
        push-branch-prefix = "jj-";
      };
      # Use delta for better diff display (same as git)
      diff = {
        tool = "delta";
      };
      # Template for commit messages
      template-aliases = {
        "builtin_log_oneline" = ''
          if(root, 
            "ROOT", 
            label(if(current_working_copy, "working_copy"), 
              separate(" ", 
                change_id.short(),
                if(description, description.first_line(), "(no description set)"),
                branches,
                tags
              )
            )
          )
        '';
      };
    };
  };

  # JJ aliases and shell functions
  home.shellAliases = {
    # JJ (Jujutsu) aliases - modern VCS
    js = "jj status";
    jl = "jj log";
    jp = "jj git push";
    jn = "jj new";
    je = "jj edit";
    jd = "jj diff";
    jr = "jj rebase";
    jsq = "jj squash";
    jb = "jj bookmark";
    jgi = "jj git import";  # Rare but useful for collaboration
    
    # Additional useful JJ aliases for busy devs
    jf = "jj git fetch";           # Fetch from remote
    jsh = "jj show";               # Show change details
    jab = "jj abandon";            # Abandon change
    jres = "jj restore";           # Restore files
    jdup = "jj duplicate";         # Duplicate change
    jspl = "jj split";             # Split change
    
    # Operation log and undo (essential for busy devs!)
    jop = "jj operation log";      # Show operation history
    jun = "jj operation undo";     # Undo last operation
    jor = "jj operation restore";  # Restore to specific operation
    
    # Bookmark management (branches)
    jbc = "jj bookmark create";    # Create bookmark
    jbm = "jj bookmark move";      # Move bookmark  
    jbd = "jj bookmark delete";    # Delete bookmark
    jbt = "jj bookmark track";     # Track remote bookmark
    
    # Rebase operations
    jrb = "jj rebase --branch";    # Rebase branch to destination
    jrs = "jj rebase --source";    # Rebase from source to destination  
    
    # Navigation and insertion
    jna = "jj new -A";             # New revision after (insert)
    jnb = "jj new -B";             # New revision before (insert)
    
    # Quick log views with revsets (from blog)
    jlm = "jj log -r '::main'";        # Everything on main branch
    jlme = "jj log -r '::main | ::@'"; # Main branch + current path  
    jlmine = "jj log -r 'mine()'";     # All your authored revisions
    jlall = "jj log -r '..'";          # Everything
  };

  programs.zsh.initContent = ''
    # JJ commit function - smart argument handling
    jc() {
      if [ $# -eq 0 ]; then
        # No arguments - open editor
        jj commit
      else
        # Has arguments - treat as message
        jj commit -m "$*"
      fi
    }

    # JJ describe function - smart argument handling
    jds() {
      if [ $# -eq 0 ]; then
        # No arguments - open editor
        jj describe
      else
        # Has arguments - treat as message
        jj describe -m "$*"
      fi
    }

    # JJ workflow functions from busy dev guide
    jstart() {
      # Start new work: fetch, create revision on specified branch (default: main)
      local base_branch="''${1:-main}"  # Default to main if no branch specified
      
      echo "ℹ️  Starting new work from '$base_branch'"
      jj git fetch && jj new "$base_branch"
    }

    jcp() {
      # Commit and push: commit current work and push to current bookmark or main
      local current_bookmark=$(jj log -r @ --no-graph -T 'bookmarks' | tr -d ' ')
      local using_main_fallback=false
      
      # Determine target bookmark
      if [ -n "$current_bookmark" ]; then
        echo "ℹ️  Using existing bookmark: $current_bookmark"
      else
        echo "ℹ️  No bookmark on current revision, using 'main'"
        current_bookmark="main"
        using_main_fallback=true
      fi
      
      # Commit the changes
      if [ $# -eq 0 ]; then
        # No arguments - interactive commit
        if ! jj commit; then
          echo "❌ Commit failed"
          return 1
        fi
      else
        # Has arguments - commit with message
        if ! jj commit -m "$*"; then
          echo "❌ Commit failed"
          return 1
        fi
      fi
      
      # Move the bookmark to the committed revision
      if [ "$using_main_fallback" = true ]; then
        echo "ℹ️  Moving 'main' bookmark to committed revision"
        if ! jj bookmark set main -r @-; then
          echo "❌ Failed to move bookmark"
          return 1
        fi
      else
        # Move the existing bookmark to the new commit to keep it tracking
        echo "ℹ️  Moving '$current_bookmark' bookmark to committed revision"
        if ! jj bookmark set "$current_bookmark" -r @-; then
          echo "❌ Failed to move bookmark"
          return 1
        fi
      fi
      
      # Push the bookmark
      echo "ℹ️  Pushing bookmark: $current_bookmark"
      if ! jj git push -b "$current_bookmark" --allow-new; then
        echo "❌ Push failed"
        return 1
      fi
      
      echo "✅ Successfully committed and pushed to $current_bookmark"
    }

    jpr() {
      # Create PR: create bookmark, commit if needed, push, create PR
      if [ $# -eq 0 ]; then
        echo "Usage: jpr <bookmark-name> [commit-message]"
        return 1
      fi
      
      local branch_name="$1"
      local commit_message="$2"
      
      # Create bookmark first (so jcp won't push to main)
      jj bookmark create "$branch_name" -r @
      
      # Check if we need to commit changes
      local has_description=$(jj log -r @ --no-graph -T 'description' | grep -v '^$' | wc -l)
      if [ "$has_description" -eq 0 ]; then
        if [ -n "$commit_message" ]; then
          # Commit with provided message
          jj commit -m "$commit_message"
        else
          # Interactive commit
          echo "ℹ️  Opening editor for commit message..."
          jj commit
        fi
      fi
      
      # Push and create PR
      jj git push -b "$branch_name" --allow-new
      
      # Create draft PR with GitHub CLI (interactive)
      if command -v gh >/dev/null 2>&1; then
        echo "Creating draft PR..."
        gh pr create --draft --fill
      else
        echo "✅ Branch pushed. Install 'gh' CLI to auto-create PRs."
      fi
    }

    jmerge() {
      # Merge two revisions: jj new parent1 parent2
      if [ $# -lt 2 ]; then
        echo "Usage: jmerge <parent1> <parent2>"
        return 1
      fi
      jj new "$1" "$2"
    }
  '';
}