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

      # Username configuration - explicit per-machine for reproducibility
      # Using builtins.getEnv is impure and breaks flake reproducibility
      usernames = {
        work = "waqas.ahmed";
        mini = "waqas";
        linux = "waqas.ahmed";
      };

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
            home-manager.extraSpecialArgs = specialArgs;
            # Backup conflicting files during migration to declarative management
            home-manager.backupFileExtension = "backup";
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
          username = usernames.work;
          hostname = "work";
          extraDarwinModules = [ ./darwin/work/homebrew.nix ];
          extraHomeModules = [];
        };

        # Mac Mini media server configuration
        # Usage: darwin-rebuild switch --flake .#mini
        mini = mkConfiguration {
          system = "aarch64-darwin";
          username = usernames.mini;
          hostname = "mini";
          extraDarwinModules = [ ./darwin/mini/homebrew.nix ];
          extraHomeModules = [ ./darwin/mini ];
        };

        # Keep 'default' as alias to 'work' for backwards compatibility
        default = self.darwinConfigurations.work;
      };

      homeConfigurations."${usernames.linux}" = mkConfiguration {
        system = "aarch64-linux";
        username = usernames.linux;
      };

      nixosConfigurations.nixos = mkConfiguration {
        system = "aarch64-linux";
        username = usernames.linux;
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

      # Flake checks for CI validation
      checks = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          # Check that all Nix files are properly formatted
          format = pkgs.runCommand "check-format" {
            buildInputs = [ pkgs.nixpkgs-fmt ];
            src = ./.;
          } ''
            cd $src
            nixpkgs-fmt --check .
            touch $out
          '';

          # Validate flake evaluation (catches syntax errors)
          flake-eval = pkgs.runCommand "check-flake-eval" { } ''
            echo "Flake evaluation successful"
            touch $out
          '';
        }
      );
    };
}
