#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 Hyprland Configuration Validator"
echo "===================================="
echo ""

# Check if we're in the dotfiles directory
if [ ! -f "flake.nix" ]; then
    echo -e "${RED}Error: Not in dotfiles directory. Please run from the root of your dotfiles.${NC}"
    exit 1
fi

# Function to check command availability
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        return 1
    fi
    return 0
}

# Track validation results
ERRORS=0
WARNINGS=0

# 1. Check Nix availability
echo "1. Checking Nix installation..."
if check_command nix; then
    echo -e "${GREEN}✓ Nix is installed${NC}"
else
    echo -e "${RED}✗ Nix is required for validation${NC}"
    exit 1
fi

# 2. Validate flake structure
echo ""
echo "2. Validating flake structure..."
if nix --extra-experimental-features 'nix-command flakes' flake metadata . &>/dev/null; then
    echo -e "${GREEN}✓ Flake structure is valid${NC}"
else
    echo -e "${RED}✗ Flake structure validation failed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# 3. Check if Hyprland module exists and is valid
echo ""
echo "3. Checking Hyprland module..."
if [ -f "modules/desktop/hyprland.nix" ]; then
    echo -e "${GREEN}✓ Hyprland module found${NC}"
    
    # Check for syntax errors using nix-instantiate
    if nix-instantiate --parse modules/desktop/hyprland.nix &>/dev/null; then
        echo -e "${GREEN}✓ Hyprland module syntax is valid${NC}"
    else
        echo -e "${RED}✗ Syntax errors in Hyprland module${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠ Hyprland module not found at expected location${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 4. Evaluate Hyprland configuration for Linux
echo ""
echo "4. Evaluating Hyprland configuration..."
if nix --extra-experimental-features 'nix-command flakes' eval .#homeConfigurations.\"chrissi@linux\".config.wayland.windowManager.hyprland.enable &>/dev/null; then
    HYPRLAND_ENABLED=$(nix --extra-experimental-features 'nix-command flakes' eval .#homeConfigurations.\"chrissi@linux\".config.wayland.windowManager.hyprland.enable 2>/dev/null)
    if [ "$HYPRLAND_ENABLED" = "true" ]; then
        echo -e "${GREEN}✓ Hyprland is enabled in configuration${NC}"
    else
        echo -e "${YELLOW}⚠ Hyprland is disabled in configuration${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${RED}✗ Failed to evaluate Hyprland configuration${NC}"
    ERRORS=$((ERRORS + 1))
fi

# 5. Check specific Hyprland settings
echo ""
echo "5. Validating specific Hyprland settings..."

# Check monitor configuration
if nix --extra-experimental-features 'nix-command flakes' eval .#homeConfigurations.\"chrissi@linux\".config.wayland.windowManager.hyprland.settings.monitor &>/dev/null; then
    echo -e "${GREEN}✓ Monitor configuration is valid${NC}"
else
    echo -e "${YELLOW}⚠ Could not evaluate monitor configuration${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check keybindings
if nix --extra-experimental-features 'nix-command flakes' eval .#homeConfigurations.\"chrissi@linux\".config.wayland.windowManager.hyprland.settings.bind &>/dev/null; then
    BIND_COUNT=$(nix --extra-experimental-features 'nix-command flakes' eval .#homeConfigurations.\"chrissi@linux\".config.wayland.windowManager.hyprland.settings.bind 2>/dev/null | grep -o '"' | wc -l)
    BIND_COUNT=$((BIND_COUNT / 2))
    echo -e "${GREEN}✓ Keybindings are valid (found approximately $BIND_COUNT bindings)${NC}"
else
    echo -e "${YELLOW}⚠ Could not evaluate keybindings${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 6. Check for required packages
echo ""
echo "6. Checking required packages..."
REQUIRED_PACKAGES=("kitty" "rofi-wayland" "waybar" "dunst" "swww")
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if nix --extra-experimental-features 'nix-command flakes' eval .#homeConfigurations.\"chrissi@linux\".config.home.packages 2>/dev/null | grep -q "$pkg"; then
        echo -e "${GREEN}✓ Package '$pkg' is included${NC}"
    else
        echo -e "${YELLOW}⚠ Package '$pkg' might be missing${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
done

# 7. Dry-run home-manager build (optional but recommended)
echo ""
echo "7. Testing home-manager build (dry-run)..."
echo "This will build the configuration without applying it."
read -p "Do you want to run the dry build? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if nix --extra-experimental-features 'nix-command flakes' build .#homeConfigurations.\"chrissi@linux\".activationPackage --dry-run 2>&1 | grep -q "would be built"; then
        echo -e "${GREEN}✓ Configuration can be built successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Dry build returned unexpected output${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "Skipping dry build..."
fi

# 8. Check for common Hyprland configuration issues
echo ""
echo "8. Checking for common issues..."

# Check for conflicting keybindings (basic check for duplicate bindings)
DUPLICATE_BINDS=$(nix --extra-experimental-features 'nix-command flakes' eval .#homeConfigurations.\"chrissi@linux\".config.wayland.windowManager.hyprland.settings.bind 2>/dev/null | grep -oE '\$mod, [A-Za-z0-9]+,' | sort | uniq -d | wc -l)
if [ "$DUPLICATE_BINDS" -eq 0 ]; then
    echo -e "${GREEN}✓ No obvious duplicate keybindings found${NC}"
else
    echo -e "${YELLOW}⚠ Found potential duplicate keybindings${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "===================================="
echo "Validation Summary"
echo "===================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed successfully!${NC}"
    echo "Your Hyprland configuration appears to be valid."
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation completed with $WARNINGS warning(s)${NC}"
    echo "Your configuration should work, but review the warnings above."
else
    echo -e "${RED}❌ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo "Please fix the errors above before applying the configuration."
fi

echo ""
echo "To apply the configuration, run:"
echo "  home-manager switch --flake .#chrissi@linux"

exit $ERRORS