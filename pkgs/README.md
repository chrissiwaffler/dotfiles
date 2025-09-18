# Custom Packages

This directory contains custom Nix packages for this dotfiles repository.

## opencode

A custom Nix package for [opencode](https://opencode.ai), an AI coding agent built for the terminal.

### Features

- **Main CLI**: Uses `bunx opencode-ai` to always run the latest version
- **TUI Component**: Builds the Go-based Terminal User Interface from source
- **Auto-updating**: The main CLI automatically uses the latest version from npm
- **Easy Updates**: Simple script to update the TUI component to new versions

### Usage

The package provides three binaries:

- `opencode`: Main CLI tool (uses latest version via bunx)
- `tui`: Terminal User Interface (built from source)
- `opencode-tui`: Wrapper for the TUI component

### Installation

The package is automatically included in the desktop profile. To use it:

```bash
# Start opencode TUI
opencode

# Run opencode with a message
opencode run "Fix the bug in the login function"

# Show help
opencode --help

# Show version
opencode --version
```

### Updating

To update the TUI component to a new version:

```bash
# Update to a specific version
./scripts/update-opencode.sh 0.9.6

# The script will:
# 1. Fetch the new version source
# 2. Update the hash in pkgs/opencode.nix
# 3. Test the build
```

The main CLI component (`opencode`) automatically uses the latest version via `bunx opencode-ai`, so it doesn't need manual updates.

### Architecture

The package consists of two main components:

1. **TUI Component** (`opencode-tui`):
   - Built from source using `buildGoModule`
   - Fetches source from GitHub
   - Builds the Go binary in `packages/tui/cmd/opencode`
   - Creates both `opencode` and `tui` binaries

2. **Main CLI** (`opencode`):
   - Simple wrapper script that uses `bunx opencode-ai`
   - Always runs the latest version from npm
   - Avoids complex dependency management during build

### Version Management

- The TUI component version is pinned in `pkgs/opencode.nix`
- The main CLI version is dynamic (always latest via bunx)
- Use the update script to update the TUI component when new releases are available