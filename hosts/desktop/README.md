# Desktop Host Configuration

This directory contains the NixOS configuration for the desktop system.

## Setup Instructions

1. Generate the hardware configuration on your NixOS system:

   ```bash
   sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
   ```

2. Copy the generated `hardware-configuration.nix` to this directory:

   ```bash
   sudo cp /etc/nixos/hardware-configuration.nix ./hosts/desktop/
   ```

3. Review and adjust `configuration.nix`:

   - Update timezone in `time.timeZone`
   - Adjust locale settings if needed
   - Modify user settings as required

4. Build and switch to the configuration:
   ```bash
   sudo nixos-rebuild switch --flake .#desktop
   ```

## Files

- `configuration.nix` - Main system configuration (tracked in git)
- `hardware-configuration.nix` - Hardware-specific configuration (gitignored)
- `README.md` - This file

## Notes

The `hardware-configuration.nix` file is gitignored because it contains machine-specific details like disk UUIDs and partition layouts that are unique to each system.

