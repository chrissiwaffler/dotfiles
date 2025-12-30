{pkgs}: let
  # Version management:
  # To update to the latest version, check the latest release at:
  # https://github.com/sst/opencode/releases
  # Then update both the version and the src hash below
  # Use: nix-prefetch-url --unpack --type sha256 "https://github.com/sst/opencode/archive/refs/tags/v<version>.tar.gz"
  version = "1.0.209";

  # Fetch the source from GitHub
  src = pkgs.fetchFromGitHub {
    owner = "sst";
    repo = "opencode";
    tag = "v${version}";
    hash = "sha256:0ky5rxp0rhh898kkw527vcc69rhwalv068zh3nxv3ci7ynx88np1";
  };

  # Build the TUI component with Go
  opencode-tui = pkgs.buildGoModule {
    pname = "opencode-tui";
    inherit version src;

    modRoot = "packages/tui";
    vendorHash = "sha256-H+TybeyyHTbhvTye0PCDcsWkcN8M34EJ2ddxyXEJkZI=";

    # Enable Go module downloads
    proxyNetwork = true;

    subPackages = ["./cmd/opencode"];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin

      # Copy the binary from the expected location
      if [ -f "/build/go/bin/opencode" ]; then
        cp /build/go/bin/opencode $out/bin/opencode
      elif [ -f "$GOPATH/bin/opencode" ]; then
        cp $GOPATH/bin/opencode $out/bin/opencode
      elif [ -f "$GOBIN/opencode" ]; then
        cp $GOBIN/opencode $out/bin/opencode
      else
        # Fallback: search for the binary
        find . -name "opencode" -type f -executable | head -1 | xargs -I {} cp {} $out/bin/opencode
      fi

      # Create symlink as 'tui'
      if [ -f "$out/bin/opencode" ]; then
        ln -sf opencode $out/bin/tui
      fi

      runHook postInstall
    '';
  };
in
  pkgs.stdenv.mkDerivation {
    pname = "opencode";
    inherit version src;

    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.bun
      pkgs.makeWrapper
    ];

    # Use pre-built npm package instead of building from source
    buildPhase = ''
      runHook preBuild

      # Since we can't download dependencies during build,
      # we'll create a simple wrapper that uses the npm package
      # This is a workaround until we can properly handle the catalog dependencies

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # Create output directories
      mkdir -p $out/bin

      # Create the main opencode wrapper script that uses the specific version
      cat > $out/bin/opencode << EOF
      #!/bin/sh
      # Use npx to run the specific opencode-ai version
      exec ${pkgs.nodejs}/bin/npx opencode-ai@${version} "\$@"
      EOF

      # Make the wrapper executable
      chmod +x $out/bin/opencode

      # Copy the TUI binary (only once)
      cp ${opencode-tui}/bin/opencode $out/bin/tui

      # Create a wrapper for the TUI as well
      cat > $out/bin/opencode-tui << 'EOF'
      #!/bin/sh
      exec ${opencode-tui}/bin/opencode "$@"
      EOF
      chmod +x $out/bin/opencode-tui

      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "AI coding agent, built for the terminal";
      homepage = "https://opencode.ai";
      license = licenses.mit;
      platforms = platforms.linux ++ platforms.darwin;
    };
  }
