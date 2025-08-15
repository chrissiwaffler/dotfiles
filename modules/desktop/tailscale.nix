{ config, lib, pkgs, ... }: {
  # Enable Tailscale service
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # Add Tailscale to system packages
  environment.systemPackages = with pkgs; [
    tailscale
  ];

  # Firewall configuration for Tailscale
  networking.firewall = {
    # Trust the Tailscale interface
    trustedInterfaces = [ "tailscale0" ];
    
    # Allow Tailscale's UDP port
    allowedUDPPorts = [ 41641 ];
    
    # Optional: Allow SSH from Tailscale network
    # This allows SSH connections from other devices on your Tailscale network
    allowedTCPPorts = [ 22 ];
  };

  # Enable SSH service for remote access
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Optional: Add SSH keys here for backup/declarative configuration
  # These keys are added in addition to ~/.ssh/authorized_keys
  # Useful for disaster recovery or fresh installations
  users.users.chrissi.openssh.authorizedKeys.keys = [
    # Example:
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-email@example.com"
  ];

  # Create a systemd service to authenticate with Tailscale
  # This will run once on boot if not already authenticated
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    
    script = ''
      # Check if we're already authenticated
      status="$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r .BackendState)"
      if [ "$status" = "Running" ]; then
        exit 0
      fi

      # NOTE: You need to generate an auth key from the Tailscale admin console
      # https://login.tailscale.com/admin/settings/keys
      # 
      # For initial setup, run manually:
      # sudo tailscale up --authkey=tskey-auth-YOUR-KEY-HERE
      #
      # For automated setup, you can:
      # 1. Store the key in a secure location (e.g., using sops-nix or agenix)
      # 2. Or run the authentication manually after first boot
      
      echo "Tailscale is not authenticated. Please run:"
      echo "sudo tailscale up"
      echo "Or if you have an auth key:"
      echo "sudo tailscale up --authkey=tskey-auth-YOUR-KEY-HERE"
    '';
  };
}