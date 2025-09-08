# modules/desktop/tools.nix
{
  config,
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    (callPackage ../../pkgs/opencode.nix {})
  ];
}
