# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Nix-based dotfiles repository using Nix Flakes and Home Manager for configuration management. The repository supports both macOS (darwin) and Linux systems.

## Key Commands

### Development Environment

```bash
# Enter development shell with formatting and linting tools
nix develop

# Format all Nix files
alejandra .

# Validate flake configuration for all systems
nix flake check --all-systems

# Apply home-manager configuration (within dev shell or with home-manager installed)
home-manager switch --flake .#chrissi@linux    # For Linux systems
home-manager switch --flake .#chrissi@darwin   # For macOS systems
```

## Architecture & Structure

### Module Organization

- **`modules/base/`**: Core functionality modules that are always loaded
  - `neovim.nix`: Neovim configuration with LSP support and kickstart.nvim integration
  - `shell.nix`: ZSH, Starship prompt, Git with Delta, and modern CLI tools
  - `tools.nix`: Development tools, languages, ML/AI packages, and cloud tools
- **`modules/desktop/`**: Desktop environment modules (currently work-in-progress)
- **`profiles/`**: Compositions of modules for different use cases
  - `base.nix`: Imports all base modules, used by all configurations

### Flake Structure

- Defines home configurations for `chrissi@linux` and `chrissi@darwin`
- Uses nixpkgs-unstable channel
- Includes overlays for neovim-nightly

## Important Implementation Details

### Missing Components

- The flake references `./home` directory in homeConfigurations, but this directory doesn't exist. When implementing home configurations, ensure this path is corrected or the directory is created.

### Cross-Platform Considerations

- The repository intelligently handles macOS vs Linux differences
- Home directory paths differ between platforms (e.g., `/Users` on macOS vs `/home` on Linux)
- Some tools have platform-specific configurations (e.g., clipboard commands)

### Module Pattern

All modules follow this structure:

```nix
{ config, lib, pkgs, ... }: {
  # Module configuration
}
```

### Development Tools Integration

- Neovim uses external kickstart.nvim configuration from a personal fork
- LSP servers and formatters are installed via Nix for consistent environments
- Shell configuration includes modern replacements for traditional Unix tools (bat for cat, eza for ls, etc.)

## Working with This Repository

When modifying configurations:

1. Edit the appropriate module in `modules/base/` or create new ones in `modules/desktop/`
2. Update profiles in `profiles/` to include new modules
3. Test changes with `nix flake check`
4. Apply configurations with `home-manager switch --flake .#<configuration>`

When adding new packages:

- Development tools go in `modules/base/tools.nix`
- Shell-specific tools and aliases go in `modules/base/shell.nix`
- Editor plugins and LSP servers go in `modules/base/neovim.nix`

