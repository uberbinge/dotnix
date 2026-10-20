{ pkgs, lib, githubUserEmail, githubUserName, ... }:
{
  # Git configuration
  programs.git = {
    enable = true;
    signing.format = "ssh";
    # Use Home Manager's signer option to avoid duplicate gpg.ssh.program values.
    # Other platforms retain Home Manager's SSH signer default (ssh-keygen).
    signing.signer = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
      "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
    ignores = [
      ".DS_Store"
      ".zed"
      ".pers"
      "git_ignored*"
    ];

    settings = {
      # User configuration
      user = {
        name = githubUserName;
        email = githubUserEmail;
        signingkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCvxBgcSK/xqo38YHW6GWRBDcZyGZ2nZahlAKYMwNYiNv1vZmolbEv2N0BaPLX1mMWVToRt0Kr5PJIzzDHP765I4qFn7Go8H3H/kS2wDgJ4GaMgp6SpcHiFqwAIfRb54igC50AFbxx4ecCCjegCQppyKP2z5Ispcz/t+jN85ZEcTcQCR5Oio4Xjf/LF7FkEJAwCMsu4FMdTOQpH6vFKm5xYK2fz6+Tf/xdrjfifQEQD+yz+2nt4t9RmjRu9kSLfmAZqzAIlOR1mNlxDBZyoqdpPtvwkvfrLF0PJnMLXvrdQ2fa/LgUfFWTe4F5/qPJinHIDmDGtLXeH8Gj2FVpvAWYIiOGIPj/Zb3uP4bKordT4YfBtVPA33L9T3fu6WJBjemYR9VympPti2bM3OfphNzPYIM8LJo/Qdvd+bcya3YUNKChM/whVmrn3dymM6tyKO0P/v0IPopgj4tEM376TdXRyeVqn6BIozqQbu9Fw5EIWgtxl5JPIOc2xEOFI0/zg+ck=";
      };

      # Aliases
      alias = {
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        visual = "!gitk";
        gone = "! git fetch -p && git for-each-ref --format '%(refname:short) %(upstream:track)' | awk '$2 == \"[gone]\" {print $1}' | xargs -r git branch -D";
      };

      # Merge and diff settings
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
        navigate = true; # Enable navigation between diff sections
        light = false; # Use dark mode
        features = "line-numbers decorations";
        syntax-theme = "Monokai Extended Bright";
      };

      # SSH signing configuration with 1Password
      gpg.format = "ssh";
      commit.gpgsign = pkgs.stdenv.hostPlatform.isDarwin;

      # Platform-specific credential helper
      credential = {
        helper = if pkgs.stdenv.hostPlatform.isDarwin then "osxkeychain" else "cache --timeout=3600";
      };

      # Automatically setup remote tracking for new branches
      push.autoSetupRemote = true;

      # Default branch for new repos
      init.defaultBranch = "main";
    };
  };

}
