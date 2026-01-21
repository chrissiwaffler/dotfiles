{
  description = "personal tooling and dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay/b5885a33eb2525154ddfdf2675975db29e6416ac";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode = {
      url = "github:sst/opencode";
    };

    kickstart-nvim = {
      url = "github:chrissiwaffler/kickstart.nvim/master";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    opencode,
    ...
  } @ inputs: let
    lib = nixpkgs.lib;
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    stateVersion = "25.05";
  in {
    inherit inputs;
    nixosModules = {
      home-manager = home-manager.nixosModules.home-manager;
    };

    homeManagerModules = {
      base = import ./profiles/base.nix;
      desktop = import ./profiles/desktop.nix;
    };

    # NixOS configurations
    nixosConfigurations = {
      desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          # Host-specific configuration
          ./hosts/desktop/configuration.nix

          # Home-manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit inputs;
                inherit stateVersion;
              };
              users.chrissi = import ./profiles/desktop.nix;
              # Backup existing files instead of failing
              backupFileExtension = "backup";
            };
          }
        ];
      };
    };

    # standalone home-manager configurations (for non-NixOS systems)
    homeConfigurations = {
      "chrissi@linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./profiles/desktop.nix
          {
            home.username = "chrissi";
            home.homeDirectory = "/home/chrissi";
            home.stateVersion = stateVersion;
          }
        ];
        extraSpecialArgs = {
          inherit inputs;
          inherit stateVersion;
        };
      };

      "chrissi@darwin" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        modules = [
          ./profiles/base.nix
          {
            home.username = "chrissi";
            home.homeDirectory = "/Users/chrissi";
            home.stateVersion = stateVersion;
          }
        ];
        extraSpecialArgs = {
          inherit inputs;
          inherit stateVersion;
        };
      };

      # Simple base configuration for any user
      "base" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          ./profiles/base.nix
          {
            home.username = let
              user = builtins.getEnv "USER";
            in
              if user == ""
              then "ubuntu"
              else user;
            home.homeDirectory = let
              user = builtins.getEnv "USER";
            in
              if user == ""
              then "/home/ubuntu"
              else "/home/${user}";
            home.stateVersion = "24.05";
            nixpkgs.config.allowUnfree = true;
          }
        ];
        extraSpecialArgs = {inherit inputs;};
      };
    };

    # dev shell for working on these configs
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          packages = with pkgs;
            [
              alejandra
              nil
              statix
            ]
            ++ [
              home-manager.packages.${system}.default
            ];

          shellHook = ''
            echo "dotfiles dev shell"
            echo "Commands:"
            echo "  home-manager switch --flake .#chrissi@linux"
            echo "  alejandra . #format nix files"
          '';
        };
      }
    );
  };
}
