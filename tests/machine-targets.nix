# Run with: nix-instantiate --eval --strict tests/machine-targets.nix
# Evaluate only target metadata and shell aliases, without fetching flake inputs.
let
  lib = {
    mkIf = condition: attrs: if condition then attrs else { };
    mkMerge = builtins.foldl' (result: attrs: result // attrs) { };
  };

  outputs = (import ../flake.nix).outputs {
    self = outputs;
    nixpkgs = { inherit lib; };
    nixpkgs-ncspot = { };
    nix-darwin.lib.darwinSystem = args: args;
    home-manager = { };
    nix-homebrew = { };
    nixvim = { };
    website-opener = { };
  };

  hsFor = hostname: username: isDarwin:
    (import ../common/home.nix {
      inherit lib hostname username;
      pkgs.stdenv = {
        inherit isDarwin;
        isLinux = !isDarwin;
      };
      githubUserEmail = "test@example.com";
      githubUserName = "test";
      specialArgs = { };
    }).programs.zsh.shellAliases.hs;

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
assert hsFor null "waqas.ahmed" false == linuxHs;
true
