{
  config,
  lib,
  pkgs,
  ...
}: {
  # Direct xdg config since we're already in home-manager context
  xdg.configFile = {
    "opencode/opencode.jsonc".source = ../../config/opencode/opencode.jsonc;
  };
}
