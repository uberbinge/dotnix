{ config, pkgs, lib, ... }:

let
  braveIcon = "brave.png";
  grafanaIcon = "grafana.png";
  iconPath = ".config/alfred/";
  homeDir = config.home.homeDirectory;
  mkSite = title: arg: icon: {
    inherit title arg;
    icon = "${homeDir}/${iconPath}${icon}";
  };
  mkTemplate = prefix: template: icon: {
    inherit prefix template;
    icon = "${homeDir}/${iconPath}${icon}";
  };

  # Personal and public sites (safe for public repo)
  personalSites = [
    (mkSite "gemini" "https://gemini.google.com/app" braveIcon)
    (mkSite "grok" "https://grok.com/" braveIcon)
    (mkSite "amazon send to kindle" "https://www.amazon.de/sendtokindle" braveIcon)
    (mkSite "amazon kindle library" "https://www.amazon.de/hz/mycd/digital-console/contentlist/pdocs/dateDsc/" braveIcon)
    (mkSite "reviews" "https://github.com/pulls/review-requested" braveIcon)

    # URL templates — "o mg some-repo" → https://github.com/moia-dev/some-repo/pulls
    (mkTemplate "mg" "https://github.com/moia-dev/{}/pulls" braveIcon)
    (mkTemplate "gh" "https://github.com/{}" braveIcon)
  ] ++ config.programs.alfredWebsiteHelper.extraPersonalSites;

  cfg = config.programs.alfredWebsiteHelper;
  personalFile = pkgs.writeText "alfred-personal-sites.json" (builtins.toJSON personalSites);
  refresh = pkgs.writeShellApplication {
    name = "alfred-sites-refresh";
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./alfred-sites.py} \
        --personal-file ${personalFile} \
        --op ${pkgs._1password-cli}/bin/op \
        --account ${lib.escapeShellArg cfg.workAccount} \
        ${lib.optionalString cfg.enableWorkSites "--allow-work"} "$@"
    '';
  };
in
{
  options.programs.alfredWebsiteHelper.enableWorkSites = lib.mkEnableOption
    "explicit authenticated work-site refresh (never used during activation)";
  options.programs.alfredWebsiteHelper.workAccount = lib.mkOption {
    type = lib.types.str;
    default = "my.1password.eu";
    description = "1Password account for manually requested work-site refresh.";
  };
  options.programs.alfredWebsiteHelper.extraPersonalSites = lib.mkOption {
    type = lib.types.listOf (lib.types.submodule {
      options = {
        title = lib.mkOption { type = lib.types.str; };
        arg = lib.mkOption { type = lib.types.str; };
        icon = lib.mkOption { type = lib.types.str; };
      };
    });
    default = [ ];
    description = "Additional personal sites for the Alfred website opener.";
  };

  config = {
    home.packages = [ refresh ];
    # Initialize public sites only. Never contact 1Password or replace a user's
    # refreshed list during activation. `run` preserves dry-run semantics.
    home.activation.initializeAlfredSites = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${refresh}/bin/alfred-sites-refresh --initialize
    '';

    # Place icons from local repository (no network dependencies)
    home.file."${iconPath}default.png".source = ./alfred-icons/brave.png;
    home.file."${iconPath}brave.png".source = ./alfred-icons/brave.png;
    home.file."${iconPath}grafana.png".source = ./alfred-icons/grafana.png;
  };
}
