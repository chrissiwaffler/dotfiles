{
  lib,
  buildNpmPackage,
  flywheel-skills,
}:
# Flywheel CLI (@paradigma-inc/flywheel), packaged from the same npm tarball
# that provides the agent skills (flake input "flywheel-skills").
# Auth: reads FLYWHEEL_API_KEY from the environment — provided by
# modules/base/secrets.nix (flywheel_api_key in secrets/api-keys.yaml).
#
# Version bump procedure:
#   The version lives in ONE place: the `flywheel-skills` URL literal in
#   flake.nix (Nix >= 2.29 rejects variable binding/interpolation in input
#   URLs), e.g. `.../flywheel-0.1.115.tgz`. After bumping the URL:
#     1. nix flake update flywheel-skills
#     2. If dependencies changed: regenerate package-lock.json
#        (npm install --package-lock-only) and update npmDepsHash below.
#   `version` here is derived at eval time from the tarball's package.json —
#   no literal to keep in sync. This is NOT import-from-derivation: the flake
#   input is already a fetched+unpacked store path, so lib.importJSON is a
#   plain eval-time read.
buildNpmPackage {
  pname = "flywheel-cli";
  version = (lib.importJSON "${flywheel-skills}/package.json").version;

  src = flywheel-skills;

  # Lockfile generated from the tarball (npm install --package-lock-only);
  # upstream doesn't ship one.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    chmod +w package-lock.json
  '';

  dontNpmBuild = true; # no build step, JS is shipped as-is
  # Upstream's install script (skills installer) doesn't apply to a nix build
  npmDepsHash = "sha256-z9PJuP8X7UlTTNdXJM6tVePqtITAgtiphTdjBuQOhv0=";

  # The npm package relies on postinstall scripts; neutralize them for the nix build
  npmFlags = ["--ignore-scripts"];

  meta = with lib; {
    description = "Flywheel CLI for the Flywheel graph/research platform";
    homepage = "https://github.com/paradigma-inc/paradigma";
    # npm marks it "UNLICENSED" (private terms) but the package is
    # distributed publicly via the npm registry.
    license = licenses.free;
    mainProgram = "flywheel";
    platforms = platforms.unix;
  };
}
