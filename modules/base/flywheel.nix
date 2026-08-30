{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.flywheel;

  # The flywheel-skills flake input (npm tarball, flake=false) unpacks to a
  # store path whose skills/ holds one directory per agent skill.
  skillsRoot = "${inputs.flywheel-skills}/skills";

  # Recursively filtered copy of skills/: keeps every file except anything
  # under a __pycache__/ directory (pruned wholesale), *.pyc files (safety net
  # for .pyc outside __pycache__), and .DS_Store files. The filter applies at
  # any depth — BUG 2 in the old module was a top-level-only name check that
  # let nested junk (e.g. flywheel-llm-proof-paper/scripts/__pycache__/*.pyc)
  # through. lib.fileset would be the usual tool, but its toSource demands a
  # genuine `path` root and Nix 2.29 exposes flake-input outPaths (and
  # builtins.storePath results) as strings, so builtins.path is the equivalent
  # pure, IFD-free filtering primitive on an already-realized input.
  skillsSource = builtins.path {
    name = "flywheel-agent-skills";
    path = skillsRoot;
    filter = p: t:
      if t == "directory"
      then baseNameOf p != "__pycache__"
      else baseNameOf p != ".DS_Store" && !lib.hasSuffix ".pyc" (baseNameOf p);
  };

  # One home.file entry per skill directory, keyed ".agents/skills/<name>".
  # The leading dot is the fix for BUG 1: the old key (agents/skills/<name>,
  # no leading dot) deployed to ~/agents/skills/, which nothing reads.
  skillDirs = lib.filterAttrs (name: type: type == "directory") (builtins.readDir skillsRoot);
in {
  options.flywheel = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the Flywheel CLI and deploy its agent skills to ~/.agents/skills/.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://flywheel.paradigma.inc";
      description = "Flywheel API origin. The auth hook appends /api, which is where the CLI expects it.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      # pkgs.flywheel comes from overlays/flywheel.nix, applied for the
      # home-manager configurations via pkgsFor. The NixOS desktop config
      # builds with useGlobalPkgs = true and never sees pkgsFor's overlays,
      # so fall back to a direct callPackage there.
      default = pkgs.flywheel or (pkgs.callPackage ../../pkgs/flywheel {inherit (inputs) flywheel-skills;});
      description = "The Flywheel CLI package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    home.file = lib.mapAttrs' (name: _:
      lib.nameValuePair ".agents/skills/${name}" {
        source = skillsSource + "/${name}";
        recursive = true;
      })
    skillDirs;

    # Write ~/.config/flywheel-cli/config.json with the sops-decrypted API key
    # at activation time (never baked into the store). Together with the
    # FLYWHEEL_API_KEY env var (modules/base/secrets.nix) these are BOTH auth
    # channels for the CLI. Runs after generateSecretsEnv — the order proven
    # working on this machine. jq --arg builds the new fields quote-safely; the
    # merge preserves any user-managed state already in the file.
    home.activation.generateFlywheelCliConfig = lib.hm.dag.entryAfter ["generateSecretsEnv"] ''
      if [[ -f "${config.sops.secrets.api-keys.path}" ]]; then
        key=$(${pkgs.yq}/bin/yq -r '.flywheel_api_key // empty' "${config.sops.secrets.api-keys.path}")
        if [[ -n "$key" ]]; then
          cfgDir="${config.home.homeDirectory}/.config/flywheel-cli"
          cfgFile="$cfgDir/config.json"
          mkdir -p "$cfgDir"
          chmod 700 "$cfgDir"
          ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
            <(cat "$cfgFile" 2>/dev/null || echo '{}') \
            <(${pkgs.jq}/bin/jq -n --arg baseUrl "${cfg.baseUrl}/api" --arg apiKey "$key" '{baseUrl: $baseUrl, apiKey: $apiKey}') \
            > "$cfgFile.tmp"
          chmod 600 "$cfgFile.tmp"
          mv "$cfgFile.tmp" "$cfgFile"
        fi
      fi
    '';

    # Remove npm-installer leftovers that would collide with the HM-managed
    # symlinks above (or shadow skill loading). Runs BEFORE Home Manager's
    # collision check (checkLinkTargets) so real directories here don't block
    # activation. Targets are exact and enumerated; every removal is guarded
    # with `[[ -d $p && ! -L $p ]]` so HM-created symlinks into /nix/store
    # survive. Preserved by construction: ~/.agents/.skill-lock.json, all
    # non-flywheel skills (hf-cli, find-skills, use-basilica, etc.) and the
    # find-skills symlink in ~/.claude/skills. ~/.claude/skills is cleaned
    # because the old npm installer deployed stale copies there too — the
    # current target is ~/.agents/skills only. Idempotent: every removal is a
    # no-op when the path is already gone.
    home.activation.cleanupFlywheelNpmLeftovers = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      agentSkills="${config.home.homeDirectory}/.agents/skills"
      claudeSkills="${config.home.homeDirectory}/.claude/skills"
      rm -f "$agentSkills/.flywheel-installed-by-universal"
      for name in flywheel flywheel-auto flywheel-llm-proof-paper flywheel-lookahead flywheel-prove flywheel-reproduce flywheel-to-graph flywheel-tree; do
        for dir in "$agentSkills/$name" "$claudeSkills/$name"; do
          if [[ -d "$dir" && ! -L "$dir" ]]; then
            rm -rf "$dir"
          fi
        done
      done
    '';
  };
}
