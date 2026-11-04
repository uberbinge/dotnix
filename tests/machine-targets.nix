# Run with: nix-instantiate --eval --strict tests/machine-targets.nix
# Evaluate target metadata and shell startup, without fetching flake inputs.
let
  lib = {
    mkIf = condition: attrs: if condition then attrs else { };
    optionalString = condition: value: if condition then value else "";
    mkMerge = values:
      if builtins.isString (builtins.head values)
      then builtins.concatStringsSep "\n" values
      else builtins.foldl' (result: attrs: result // attrs) { } values;
  };

  outputs = (import ../flake.nix).outputs {
    self = outputs;
    nixpkgs = { inherit lib; };
    nix-darwin.lib.darwinSystem = args: args;
    home-manager = { };
    nix-homebrew = { };
    website-opener = { };
  };

  homeForSystem = hostname: username: isDarwin: isNixOS:
    import ../common/home.nix {
      inherit lib hostname username isNixOS;
      pkgs.stdenv.hostPlatform = {
        inherit isDarwin;
        isLinux = !isDarwin;
      };
      githubUserEmail = "test@example.com";
      githubUserName = "test";
      specialArgs = { };
    };

  hsForSystem = hostname: username: isDarwin: isNixOS:
    (homeForSystem hostname username isDarwin isNixOS).programs.zsh.shellAliases.hs;
  hsFor = hostname: username: isDarwin: hsForSystem hostname username isDarwin false;
  markerFor = hostname: username: isDarwin: isNixOS:
    (homeForSystem hostname username isDarwin isNixOS).home.file.".config/dotnix/target".text;
  initFor = hostname: username: isDarwin: isNixOS:
    (homeForSystem hostname username isDarwin isNixOS).programs.zsh.initContent;
  has = needle: haystack: builtins.length (builtins.split needle haystack) > 1;
  personalHs = "cd ~/dev/dotnix && sudo darwin-rebuild switch --flake .#macbook";
  legacyDarwinHs = "cd ~/dev/dotnix && sudo darwin-rebuild switch --flake .#$([[ $(whoami) == 'waqas' ]] && echo mini || echo work)";
  linuxHs = "cd ~/dev/dotnix && sudo nixos-rebuild switch --flake .#nixos";
in
assert outputs.darwinConfigurations.macbook.specialArgs.username == "waqas";
assert outputs.darwinConfigurations.macbook.specialArgs.hostname == "macbook";
assert outputs.darwinConfigurations.work.specialArgs.username == "waqas.ahmed";
assert !(outputs.darwinConfigurations ? mac-personal);
assert outputs.darwinConfigurations.mini.specialArgs.username == "waqas";
assert outputs.darwinConfigurations.default.specialArgs.hostname == "work";
assert hsFor "macbook" "waqas" true == personalHs;
assert hsFor "macbook" "waqas.ahmed" true == personalHs;
assert hsFor "mini" "waqas" true == legacyDarwinHs;
assert hsFor "work" "waqas.ahmed" true == legacyDarwinHs;
assert hsFor null "waqas" true == legacyDarwinHs;
assert hsFor null "waqas.ahmed" false == "cd ~/dev/dotnix && home-manager switch --flake .#waqas.ahmed";
assert hsForSystem null "waqas.ahmed" false true == linuxHs;
assert markerFor "macbook" "waqas" true false == "macbook";
assert markerFor "mini" "waqas" true false == "mini";
assert markerFor "work" "waqas.ahmed" true false == "work";
assert markerFor null "waqas.ahmed" false false == "linux-hm";
assert markerFor null "waqas.ahmed" false true == "nixos";
assert has "MISE_ACTIVATE_SHIMS=false" (initFor "macbook" "waqas" true false);
assert has "/opt/homebrew/bin/mise activate zsh" (initFor "macbook" "waqas" true false);
assert !(has "/opt/homebrew/bin/mise" (initFor null "waqas.ahmed" false false));
true
