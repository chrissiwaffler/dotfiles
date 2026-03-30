{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  options.secrets = {
    apiKeysFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = ../../secrets/api-keys.yaml;
      description = "Path to the API keys file. Set to null to disable loading API keys.";
    };

    apiKeysEnable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to automatically load all API keys from the api-keys file into environment variables";
    };
  };

  config = let
    apiKeysFile = config.secrets.apiKeysFile;
    apiKeysExists = apiKeysFile != null && builtins.pathExists apiKeysFile;
  in
    lib.mkIf (apiKeysExists && config.secrets.apiKeysEnable) {
      home.packages = [pkgs.yq];

      sops = {
        age.keyFile = lib.mkDefault "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        defaultSopsFormat = "yaml";
        validateSopsFiles = true;

        # Mount entire api-keys.yaml file as-is using empty key
        secrets.api-keys = {
          sopsFile = apiKeysFile;
          key = "";  # Empty key = entire file mounted as-is
        };
      };

      # Load all top-level keys from the YAML as environment variables
      programs.zsh.initExtra = lib.mkAfter ''
        # Load API keys from decrypted YAML file
        if [[ -f "${config.sops.secrets.api-keys.path}" ]]; then
          # Extract all top-level keys and export as UPPERCASE env vars
          eval $(${pkgs.yq}/bin/yq -r '
            to_entries | .[] |
            select(.key != "sops") |
            "export " + (.key | ascii_upcase) + "=" + (.value | @sh)
          ' "${config.sops.secrets.api-keys.path}")
        fi
      '';
    };
}
