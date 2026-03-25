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

  sops = {
    # Age key file location (user-specific)
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    # Default secrets file for desktop host
    defaultSopsFile = ../../hosts/desktop/secrets.yaml;
    defaultSopsFormat = "yaml";

    # Validate at build time
    validateSopsFiles = true;

    # Define AWS bearer token secret
    secrets.AWS_BEARER_TOKEN_BEDROCK = {
      # Will be decrypted to: ${config.sops.secrets.AWS_BEARER_TOKEN_BEDROCK.path}
      # Location: $XDG_RUNTIME_DIR/secrets.d/AWS_BEARER_TOKEN_BEDROCK
    };
  };

  # Export as environment variable (points to file path, not raw value)
  # Programs should read the file: cat $AWS_BEARER_TOKEN_BEDROCK
  home.sessionVariables = {
    AWS_BEARER_TOKEN_BEDROCK = "${config.sops.secrets.AWS_BEARER_TOKEN_BEDROCK.path}";
  };
}
