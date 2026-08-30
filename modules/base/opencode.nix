{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  xdg.configFile = {
    # opencode clobbers these on every switch otherwise (stale .backup files block activation)
    "opencode/opencode.jsonc".force = true;
    "opencode/oh-my-openagent.jsonc".force = true;
    "opencode/tui.json".force = true;
    "opencode/opencode.jsonc".source = ../../config/opencode/opencode.jsonc;
    "opencode/oh-my-openagent.jsonc".source = ../../config/opencode/oh-my-openagent.jsonc;
    # TUI theme (moved out of opencode.jsonc — deprecated there since opencode 1.17)
    "opencode/tui.json".source = ../../config/opencode/tui.json;

    # NixOS management skill for AI agents
    "opencode/skills/nixos-managing" = {
      source = "${inputs.nixos-management-skill}/nixos-managing";
      recursive = true;
    };
  };

  home.packages = [
    # AI coding assistant from flake input
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
