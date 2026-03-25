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

  # Load token value directly into environment via shell init
  programs.zsh.initExtra = lib.mkAfter ''
    # Load AWS Bedrock token from sops-managed secret file
    if [[ -f "${config.sops.secrets.AWS_BEARER_TOKEN_BEDROCK.path}" ]]; then
      export AWS_BEARER_TOKEN_BEDROCK="$(cat "${config.sops.secrets.AWS_BEARER_TOKEN_BEDROCK.path}")"
    fi
  '';
}
