{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.services.opencode-server;
in {
  options.services.opencode-server = {
    enable = mkEnableOption "OpenCode headless server for remote access";

    port = mkOption {
      type = types.port;
      default = 4096;
      description = "Port for the OpenCode HTTP server";
    };

    hostname = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Hostname to bind to (0.0.0.0 for all interfaces)";
    };

    user = mkOption {
      type = types.str;
      default = "chrissi";
      description = "User to run the OpenCode server as";
    };

    workingDirectory = mkOption {
      type = types.str;
      default = "/home/${cfg.user}";
      description = "Working directory for the OpenCode server";
    };

    enableAuth = mkOption {
      type = types.bool;
      default = false;
      description = "Enable HTTP basic authentication";
    };

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing the server password (for HTTP basic auth)";
      example = "/run/secrets/opencode-password";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional command-line arguments to pass to opencode serve";
      example = ["--mdns" "--cors http://localhost:3000"];
    };
  };

  config = mkIf cfg.enable {
    systemd.services.opencode-server = {
      description = "OpenCode headless server for AI coding assistant";
      documentation = ["https://opencode.ai/docs/server"];
      after = ["network-online.target" "sops-nix.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        WorkingDirectory = cfg.workingDirectory;
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        # Note: ProtectHome disabled to allow working in any project directory
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        # ReadWritePaths = [
        #   "/home/${cfg.user}/.local/share/opencode"
        #   "/home/${cfg.user}/.config/opencode"
        #   "/home/${cfg.user}/.cache/opencode"
        # ];

        # Environment
        Environment = mkMerge [
          [
            "OPENCODE_CONFIG_DIR=/home/${cfg.user}/.config/opencode"
          ]
          (mkIf cfg.enableAuth [
            "OPENCODE_SERVER_USERNAME=opencode"
          ])
        ];

        # Load secrets and password from environment files
        EnvironmentFile = mkMerge [
          (mkIf (cfg.enableAuth && cfg.passwordFile != null) [cfg.passwordFile])
          ["/run/secrets-rendered/opencode-env"]
        ];

        # Command
        ExecStart = let
          args = [
            "${inputs.opencode.packages.${pkgs.system}.default}/bin/opencode"
            "serve"
            "--port ${toString cfg.port}"
            "--hostname ${cfg.hostname}"
          ] ++ cfg.extraArgs;
        in "${lib.concatStringsSep " " args}";
      };
    };

    # Ensure data directories exist
    systemd.tmpfiles.rules = [
      "d /home/${cfg.user}/.local/share/opencode 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/.config/opencode 0755 ${cfg.user} users -"
      "d /home/${cfg.user}/.cache/opencode 0755 ${cfg.user} users -"
    ];

    # Open firewall port if needed (only for Tailscale, so disabled by default)
    # networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
  };
}
