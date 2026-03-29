{
  pkgs,
  lib,
  inputs,
  stateVersion,
  ...
}: {
  imports = [
    ../modules/base/git.nix
  ];

  programs.home-manager.enable = true;

  home = {
    username = lib.mkDefault "chrissi";
    homeDirectory = lib.mkDefault "/Users/chrissi";
    stateVersion = lib.mkDefault stateVersion;
  };

  # Pass inputs to all module imports
  _module.args = {inherit inputs;};
}
