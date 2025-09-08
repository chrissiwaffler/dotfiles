# Tailscale Setup Instructions

## Initial Configuration

Tailscale has been added to your NixOS configuration. To apply the changes:

```bash
# Rebuild your NixOS system
sudo nixos-rebuild switch --flake .#desktop
```

## Authentication

After the system rebuild, you need to authenticate with Tailscale:

### Option 1: Interactive Authentication (Recommended for first-time setup)

```bash
# Run this command and follow the prompts
sudo tailscale up
```

This will provide you with a URL to authenticate via your browser.

### Option 2: Using an Auth Key (For automated setups)

1. Go to the Tailscale admin console: https://login.tailscale.com/admin/settings/keys
2. Generate a new auth key (optionally make it reusable if you plan to reinstall)
3. Run:

```bash
sudo tailscale up --authkey=tskey-auth-YOUR-KEY-HERE
```

## Connecting from Your MacBook

1. Install Tailscale on your MacBook:
   - Download from: https://tailscale.com/download/mac
   - Or via Homebrew: `brew install --cask tailscale`

2. Sign in with the same account you used for your desktop

3. Your desktop will appear in the Tailscale network with its hostname

4. Connect via SSH:
```bash
# Using the Tailscale hostname (usually your machine name)
ssh chrissi@desktop

# Or using the Tailscale IP (found in Tailscale app)
ssh chrissi@100.x.x.x
```

## Security Features Configured

- **Firewall**: Configured to trust the `tailscale0` interface
- **SSH**: Enabled with password authentication disabled (key-only)
- **Network Access**: Works from anywhere with internet connection, not just home network

## Useful Commands

```bash
# Check Tailscale status
tailscale status

# View your Tailscale IP
tailscale ip -4

# Enable/disable Tailscale
sudo tailscale down  # Disconnect
sudo tailscale up    # Reconnect

# View network devices
tailscale status --peers
```

## Troubleshooting

If you can't connect:

1. Ensure Tailscale is running on both machines:
   ```bash
   systemctl status tailscale
   ```

2. Check if authenticated:
   ```bash
   tailscale status
   ```

3. Verify firewall isn't blocking:
   ```bash
   sudo iptables -L -n | grep tailscale
   ```

4. Ensure SSH is running:
   ```bash
   systemctl status sshd
   ```

## SSH Key Setup (Required for Remote Access)

For passwordless SSH access from your MacBook:

1. On your MacBook, generate an SSH key if you don't have one:
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

2. Get your public key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```

3. **IMPORTANT FOR REMOTE REBOOT ACCESS**: Add your public key to the NixOS configuration in `modules/desktop/tailscale.nix`:
   ```nix
   users.users.chrissi.openssh.authorizedKeys.keys = [
     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-email@example.com"
   ];
   ```
   
   This ensures you can SSH in even after a reboot when you're not physically present to log in.

4. Rebuild the configuration:
   ```bash
   sudo nixos-rebuild switch --flake .#desktop
   ```

## Remote Reboot Considerations

**Yes, you can SSH in after a remote reboot!** The system is configured so that:

- Tailscale starts automatically at boot (system service)
- SSH daemon starts automatically at boot
- No local login is required for these services to run
- Your SSH key is stored in the NixOS configuration (not just in your home directory)

To safely reboot remotely:
```bash
# While connected via SSH
sudo reboot

# Wait a few minutes, then reconnect
ssh chrissi@desktop
```