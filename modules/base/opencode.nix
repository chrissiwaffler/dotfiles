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

    # NixOS management skill for AI agents
    "opencode/skills/nixos-managing" = {
      source = "${inputs.nixos-management-skill}/nixos-managing";
      recursive = true;
    };
  };

  home.packages = [
    # AI coding assistant from flake input
    inputs.opencode.packages.${pkgs.system}.default
  ];
}
