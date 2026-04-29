{
  pkgs,
  lib,
  inputs,
  stateVersion,
  ...
}: {
  imports = [
    ../modules/base/git.nix
    ../modules/base/neovim.nix
    ../modules/base/opencode.nix
    ../modules/base/secrets.nix
  ];

  programs.home-manager.enable = true;

  # API keys automatically loaded from secrets/api-keys.yaml
  # (enabled by default in secrets.nix module)

  home = {
    username = lib.mkDefault "chrissi";
    homeDirectory = lib.mkDefault "/Users/chrissi";
    stateVersion = lib.mkDefault stateVersion;

    packages = with pkgs; [
      # Secret management tools
      ssh-to-age
      sops

      # Nix language server
      nixd
    ];
  };

  # Pass inputs to all module imports
  _module.args = {inherit inputs;};
}
