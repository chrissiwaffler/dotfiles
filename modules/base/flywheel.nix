{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: let
  # Flywheel agent skills from the @paradigma-inc/flywheel npm package tarball
  # (flake input "flywheel-skills", unpacked by Nix into a store path).
  # Each top-level folder in the package's skills/ dir is linked to
  # ~/.agents/skills/<name>. Build artifacts (__pycache__, *.pyc, .DS_Store)
  # shipped upstream are filtered out.
  skillsRoot = "${inputs.flywheel-skills}/skills";

  isJunk = name: builtins.match "(__pycache__|.*\\.pyc|\\.DS_Store)" name != null;

  skillDirs = lib.filterAttrs (name: type: type == "directory" && !isJunk name) (builtins.readDir skillsRoot);

  # Flywheel CLI packaged from the same npm tarball (see pkgs/flywheel/).
  flywheel-cli = pkgs.callPackage ../../pkgs/flywheel {
    inherit (inputs) flywheel-skills;
  };

  # Prod API origin; the CLI normalizes the /api suffix.
  flywheelBaseUrl = "https://flywheel.paradigma.inc";
in {
  # --- Flywheel agent skills ---
  home.file = lib.mapAttrs' (name: _:
    lib.nameValuePair "agents/skills/${name}" {
      source = skillsRoot + "/${name}";
      recursive = true;
    })
  skillDirs;

  # --- Flywheel CLI ---
  home.packages = [flywheel-cli];

  # --- CLI auth via sops-managed API key (flywheel_api_key) ---
  # Requires modules/base/secrets.nix. The key itself is NOT copied into the
  # Nix store: at activation time yq extracts it from the sops-decrypted
  # api-keys.yaml into ~/.config/flywheel-cli/config.json (chmod 600) — the
  # same file `flywheel setup --mode cli` would write. The key is also
  # exported as $FLYWHEEL_API_KEY via ~/.config/zsh/secrets.zsh.
  home.activation.generateFlywheelCliConfig = lib.hm.dag.entryAfter ["generateSecretsEnv"] ''
    if [[ -f "${config.sops.secrets.api-keys.path}" ]]; then
      key=$(${pkgs.yq}/bin/yq -r '.flywheel_api_key // empty' "${config.sops.secrets.api-keys.path}")
      if [[ -n "$key" ]]; then
        cfgDir="${config.home.homeDirectory}/.config/flywheel-cli"
        mkdir -p "$cfgDir"
        chmod 700 "$cfgDir"
        # merge-write baseUrl/apiKey, preserving user-managed profile state
        ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
          <(cat "$cfgDir/config.json" 2>/dev/null || echo '{}') \
          <(printf '{"baseUrl": "%s/api", "apiKey": "%s"}' "${flywheelBaseUrl}" "$key") \
          > "$cfgDir/config.json.tmp"
        chmod 600 "$cfgDir/config.json.tmp"
        mv "$cfgDir/config.json.tmp" "$cfgDir/config.json"
      fi
    fi
  '';
}
