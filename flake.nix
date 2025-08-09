{
  description = "personal tooling and dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay/b5885a33eb2525154ddfdf2675975db29e6416ac";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # personal neovim config
    kickstart-nvim = {
      url = "github:chrissiwaffler/kickstart.nvim/master";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    nixosModules = {
      home-manager = home-manager.nixosModules.home-manager;

      # configs
      config-base = import ./profiles/base.nix inputs;
      # could define a minimal version and add it here
    };

    # standalone home-manager configurations
    homeConfigurations = {
      "chrissi@linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [(import ./home inputs)];
        extraSpecialArgs = {inherit inputs;};
      };

      "chrissi@darwin" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.aarch64-darwin;
        modules = [(import ./home inputs)];
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
