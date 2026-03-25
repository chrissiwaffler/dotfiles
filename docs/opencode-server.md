# OpenCode Server Setup

This configuration runs OpenCode as a persistent systemd service on your NixOS desktop, accessible remotely via Tailscale from your MacBook.

## Architecture

```
┌─────────────┐                    ┌──────────────────────────┐
│   MacBook   │    Tailscale       │  NixOS Desktop           │
│             │◄──────────────────►│                          │
│  opencode   │    100.x.x.x:4096  │  systemd                 │
│  attach     │                    │  └─ opencode serve       │
└─────────────┘                    │     (always running)     │
                                   └──────────────────────────┘
```

## How It Works

1. **systemd service** runs `opencode serve` on boot
2. **Tailscale** provides secure encrypted access across devices
3. **MacBook** connects directly via `opencode attach http://tailscale-ip:4096`
4. **Sessions persist** in `~/.local/share/opencode/` on desktop

## Usage

### From MacBook

1. **Get your desktop's Tailscale IP**:

   ```bash
   # On desktop
   tailscale ip -4
   # Example output: 100.101.102.103
   ```

2. **Connect from MacBook** (via SSH or directly):

   ```bash
   # Option 1: SSH into desktop, then attach locally
   ssh chrissi@desktop-tailscale-ip
   opencode attach http://127.0.0.1:4096

   # Option 2: Direct connection from MacBook (if opencode installed)
   opencode attach http://desktop-tailscale-ip:4096
   ```

3. **Work as normal** — sessions persist when you disconnect

4. **Reconnect anytime** — same command, sessions still there

### Managing the Service

```bash
# Check status
systemctl status opencode-server

# View logs
journalctl -u opencode-server -f

# Restart service
sudo systemctl restart opencode-server

# Stop service temporarily
sudo systemctl stop opencode-server

# Disable service from auto-starting
sudo systemctl disable opencode-server
```

## Configuration Options

Edit `/home/chrissi/dotfiles/hosts/desktop/configuration.nix`:

```nix
services.opencode-server = {
  enable = true;                    # Enable/disable the service
  port = 4096;                      # HTTP port (default: 4096)
  hostname = "0.0.0.0";             # Listen on all interfaces
  user = "chrissi";                 # Run as this user
  workingDirectory = "/home/chrissi"; # Default working directory

  # Optional: Enable HTTP basic authentication
  # enableAuth = true;
  # passwordFile = "/run/secrets/opencode-password";

  # Optional: Additional arguments
  # extraArgs = [ "--mdns" "--cors http://localhost:3000" ];
};
```

After changing configuration:

```bash
sudo nixos-rebuild switch --flake .#desktop
```

## Adding Authentication (Optional)

For additional security beyond Tailscale:

1. **Create password file** (using sops or plain file):

   ```bash
   # Simple approach (not tracked in git)
   echo "OPENCODE_SERVER_PASSWORD=your-secure-password" | sudo tee /etc/opencode-password
   sudo chmod 600 /etc/opencode-password
   ```

2. **Update configuration**:

   ```nix
   services.opencode-server = {
     enable = true;
     enableAuth = true;
     passwordFile = "/etc/opencode-password";
     # ... other options
   };
   ```

3. **Rebuild and connect with auth**:
   ```bash
   opencode attach http://opencode:your-secure-password@desktop-ip:4096
   ```

## Troubleshooting

### Service won't start

```bash
# Check detailed logs
journalctl -u opencode-server -n 50

# Check if port is already in use
sudo ss -tlnp | grep 4096

# Check if opencode binary is available
which opencode
```

### Can't connect from MacBook

```bash
# Verify Tailscale connection
tailscale ping desktop-hostname

# Check if port is listening
# (on desktop)
sudo ss -tlnp | grep 4096

# Check firewall (should be fine with Tailscale)
sudo iptables -L -n | grep 4096
```

### Sessions not persisting

```bash
# Check if data directory exists and has correct permissions
ls -la ~/.local/share/opencode/

# Check service logs for errors
journalctl -u opencode-server -f
```

## Benefits Over SSH + tmux

✅ **Auto-starts on boot** — No manual startup needed  
✅ **Automatic crash recovery** — systemd restarts on failure  
✅ **Proper service management** — Standard systemd commands  
✅ **No SSH dependency** — Direct Tailscale connection  
✅ **Multi-device access** — Connect from phone, tablet, etc.  
✅ **Declarative config** — Version-controlled in dotfiles

## Next Steps

- [ ] Test the service after rebuild: `systemctl status opencode-server`
- [ ] Get Tailscale IP: `tailscale ip -4`
- [ ] Connect from MacBook: `opencode attach http://tailscale-ip:4096`
- [ ] Verify sessions persist across reconnections
- [ ] (Optional) Add authentication for extra security
