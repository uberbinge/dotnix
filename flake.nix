{
  description = "System configuration flake for macOS, Linux, and NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    website-opener.url = "github:uberbinge/alfred-website-helper";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, nix-homebrew, nixvim, website-opener }:
    let
      lib = nixpkgs.lib;
      systems = [ "aarch64-darwin" "aarch64-linux" ];
      forAllSystems = lib.genAttrs systems;

      mkConfiguration = { system, username, hostname ? null, isNixOS ? false }:
        let
          pkgs = import nixpkgs { inherit system; };
          specialArgs = inputs // {
            inherit system username hostname;
            githubUserEmail = "1692495+uberbinge@users.noreply.github.com";
            githubUserName = "uberbinge";
          };

          # Common Home Manager config (reusable across platforms)
          mkCommonHomeConfig = { 
            home-manager.useGlobalPkgs = lib.mkForce true;
            home-manager.useUserPackages = lib.mkForce true;
            home-manager.extraSpecialArgs = specialArgs;
            home-manager.users.${username}.imports = [
              ./common/home.nix
              nixvim.homeManagerModules.nixvim
            ];
          };

          darwinModules = lib.optionalAttrs (system == "aarch64-darwin") {
            nix-homebrew = {
              enable = lib.mkForce true;
              enableRosetta = lib.mkForce true;
              user = lib.mkForce username;
            };
          };

          nixosModules = lib.optionalAttrs isNixOS {
            # Add NixOS-specific modules here if needed
          };

        in
          lib.recursiveUpdate
            (if isNixOS then
              nixpkgs.lib.nixosSystem {
                inherit system specialArgs;
                modules = [
                  ./linux/configuration.nix
                  home-manager.nixosModules.home-manager
                  mkCommonHomeConfig
                  {
                    home-manager.users.${username} = {
                      imports = [ ./linux/home.nix ];
                    };
                  }
                  nixosModules
                ];
              }
            else if system == "aarch64-darwin" then
              nix-darwin.lib.darwinSystem {
                inherit system specialArgs;
                modules = [
                  ./darwin/configuration.nix
                  home-manager.darwinModules.home-manager
                  mkCommonHomeConfig
                  {
                    home-manager.users.${username} = { pkgs, ... }: {
                      imports = [ ./darwin/home.nix ];          
                      home.packages = [ website-opener.packages.${system}.default ];
                    };
                  }
                  nix-homebrew.darwinModules.nix-homebrew
                  darwinModules
                ];
              }
            else
              home-manager.lib.homeManagerConfiguration {
                pkgs = pkgs;
                extraSpecialArgs = specialArgs;
                modules = [
                  mkCommonHomeConfig
                  ./linux/home.nix
                ];
              })
            { };

    in
    {
      # Universal Darwin configuration - works with any hostname
      darwinConfigurations = let
        # Single reusable macOS configuration
        universalMacConfig = mkConfiguration {
          system = "aarch64-darwin";
          username = "waqas.ahmed";  # Update this to your username
          hostname = "mac";  # Generic hostname, actual hostname doesn't matter
        };
      in {
        # Universal configuration that works on any macOS machine
        # Usage: darwin-rebuild switch --flake .#default
        default = universalMacConfig;
      };

      homeConfigurations."waqas" = mkConfiguration {
        system = "aarch64-linux";
        username = "waqas";  # Update this to your username
      };

      nixosConfigurations.nixos = mkConfiguration {
        system = "aarch64-linux";
        username = "waqas";  # Update this to your username
        isNixOS = true;
      };

      darwinPackages = self.darwinConfigurations.default.pkgs;

      # Add a devShell for each system
      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              nixpkgs-fmt
              nil
            ];
          };
        }
      );
    };
}
