#!/usr/bin/env bash
# Script to update opencode to the latest version

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 0.9.6"
  echo ""
  echo "To find the latest version, check: https://github.com/sst/opencode/releases"
  exit 1
fi

VERSION="$1"
echo "Updating opencode to version $VERSION"

# Get the hash for the new version
echo "Fetching hash for version $VERSION..."
HASH=$(nix-prefetch-url --unpack --type sha256 "https://github.com/sst/opencode/archive/refs/tags/v$VERSION.tar.gz")
# Add the sha256: prefix that Nix expects
HASH="sha256:$HASH"

echo "Updating pkgs/opencode.nix..."
sed -i "s/version = \"[^\"]*\";/version = \"$VERSION\";/" pkgs/opencode.nix
sed -i "s/hash = \"[^\"]*\";/hash = \"$HASH\";/" pkgs/opencode.nix

echo "Fetching vendor hash for Go modules..."
# First, let the build fail to get the correct vendor hash
if nix build .#opencode --no-link 2>&1 | grep -q "got:"; then
  VENDOR_HASH=$(nix build .#opencode --no-link 2>&1 | grep "got:" | awk '{print $2}' | tr -d '\n')
  echo "Updating vendor hash to: $VENDOR_HASH"
  sed -i "s/vendorHash = \"[^\"]*\";/vendorHash = \"$VENDOR_HASH\";/" pkgs/opencode.nix
fi

echo "Updated opencode to version $VERSION"
echo "Hash: $HASH"

echo "Testing build..."
nix build .#opencode

echo "Success! opencode has been updated to version $VERSION"

