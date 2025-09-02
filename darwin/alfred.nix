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
  
  # Personal and public sites (safe for public repo)
  personalSites = [
    (mkSite "gemini" "https://gemini.google.com/app" braveIcon)
    (mkSite "paperless" "https://paperless.ti.waqas.dev" braveIcon)
    (mkSite "immich" "https://immich.ti.waqas.dev" braveIcon)
    (mkSite "jellyfin" "https://jelly.ti.waqas.dev" braveIcon)
    (mkSite "grok" "https://grok.com/" braveIcon)
    (mkSite "amazon send to kindle" "https://www.amazon.de/sendtokindle" braveIcon)
    (mkSite "amazon kindle library" "https://www.amazon.de/hz/mycd/digital-console/contentlist/pdocs/dateDsc/" braveIcon)
    (mkSite "reviews" "https://github.com/pulls/review-requested" braveIcon)
  ];
  
  # Work sites - dynamically generated from 1Password at activation time
  # No need to define them here since 1Password is the source of truth
in
{
  # Generate complete sites.json from 1Password as single source of truth
  home.activation.generateSitesFromOP = lib.hm.dag.entryAfter ["writeBoundary"] ''
    export PATH="/opt/homebrew/bin:$PATH"
    sites_file="$HOME/.config/alfred/sites.json"
    
    if command -v op >/dev/null 2>&1; then
      echo "Generating Alfred sites from 1Password work-urls..."
      
      # Get work URLs directly from 1Password JSON structure
      work_data=$(op item get work-urls --account=my.1password.eu --format=json 2>/dev/null)
      
      if [ -n "$work_data" ]; then
        # Extract work sites using jq and combine with personal sites
        personal_sites='${builtins.toJSON personalSites}'
        echo "$personal_sites" | ${pkgs.jq}/bin/jq --argjson work_json "$work_data" '
          . + [
            $work_json.fields[] | 
            select(.type == "URL" and .label != null and .value != null) | 
            {
              "title": .label,
              "arg": .value,
              "icon": "'$HOME'/.config/alfred/brave.png"
            }
          ]
        ' > "$sites_file"
        echo "Alfred sites generated from 1Password"
      else
        # Fallback to personal sites only
        echo '${builtins.toJSON personalSites}' > "$sites_file"
        echo "Using personal sites only (work-urls not found)"
      fi
    else
      # Fallback to personal sites only
      echo '${builtins.toJSON personalSites}' > "$sites_file"
      echo "1Password CLI not available, using personal sites only"
    fi
  '';

  # Place icons from local repository (no network dependencies)
  home.file."${iconPath}default.png".source = ./alfred-icons/brave.png;
  home.file."${iconPath}brave.png".source = ./alfred-icons/brave.png;
  home.file."${iconPath}grafana.png".source = ./alfred-icons/grafana.png;

}
