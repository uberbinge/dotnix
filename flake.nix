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
    website-opener = {
      url = "github:uberbinge/alfred-website-helper";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager, nix-homebrew, nixvim, website-opener }:
    let
      lib = nixpkgs.lib;
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = lib.genAttrs systems;
      
      # Default username (can be overridden via FLAKE_USERNAME env var)
      defaultUsername = "waqas.ahmed";
      
      # Get username from environment or use default
      currentUsername = 
        let envUser = builtins.getEnv "FLAKE_USERNAME";
        in if envUser != "" then envUser else defaultUsername;

      mkConfiguration = { system, username, hostname ? null, isNixOS ? false, extraDarwinModules ? [], extraHomeModules ? [] }:
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
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = specialArgs;
            home-manager.users.${username}.imports = [
              ./common/home.nix
              nixvim.homeModules.nixvim
            ];
          };

          darwinModules = lib.optionalAttrs (system == "aarch64-darwin") {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = username;
              autoMigrate = true;
            };
          };

          nixosModules = lib.optionalAttrs isNixOS {
            # Add NixOS-specific modules here if needed
          };

        in
          if isNixOS then
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
                    imports = [ ./darwin/home.nix ] ++ extraHomeModules;
                    home.packages = [ website-opener.packages.${system}.default ];
                  };
                }
                nix-homebrew.darwinModules.nix-homebrew
                darwinModules
              ] ++ extraDarwinModules;
            }
          else
            home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              extraSpecialArgs = specialArgs;
              modules = [
                mkCommonHomeConfig
                ./linux/home.nix
              ];
            };

    in
    {
      # Darwin configurations for different machines
      darwinConfigurations = {
        # Work Mac configuration
        # Usage: darwin-rebuild switch --flake .#work
        work = mkConfiguration {
          system = "aarch64-darwin";
          username = currentUsername;  # Uses FLAKE_USERNAME env var or default
          hostname = "work";
          extraDarwinModules = [ ./darwin/work/homebrew.nix ];
          extraHomeModules = [];
        };

        # Mac Mini media server configuration
        # Usage: darwin-rebuild switch --flake .#mini
        mini = mkConfiguration {
          system = "aarch64-darwin";
          username = "waqas";
          hostname = "mini";
          extraDarwinModules = [ ./darwin/mini/homebrew.nix ];
          extraHomeModules = [ ./darwin/mini ];
        };

        # Keep 'default' as alias to 'work' for backwards compatibility
        default = self.darwinConfigurations.work;
      };

      homeConfigurations."${currentUsername}" = mkConfiguration {
        system = "aarch64-linux";
        username = currentUsername;  # Uses FLAKE_USERNAME env var or default  
      };

      nixosConfigurations.nixos = mkConfiguration {
        system = "aarch64-linux";
        username = currentUsername;  # Uses FLAKE_USERNAME env var or default
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

      # Formatter for `nix fmt`
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
    };
}
