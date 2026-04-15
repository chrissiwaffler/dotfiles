{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  xdg.configFile = {
    "opencode/opencode.jsonc".source = ../../config/opencode/opencode.jsonc;
    "opencode/oh-my-openagent.jsonc".source = ../../config/opencode/oh-my-openagent.jsonc;
  };

  home.packages = [
    # AI coding assistant from flake input
    inputs.opencode.packages.${pkgs.system}.default
  ];
}
