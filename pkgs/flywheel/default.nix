{
  lib,
  buildNpmPackage,
  nodejs,
  flywheel-skills,
}:
# Flywheel CLI (@paradigma-inc/flywheel), packaged from the same npm tarball
# that provides the agent skills (flake input "flywheel-skills").
# Auth: reads FLYWHEEL_API_KEY from the environment — provided by
# modules/base/secrets.nix (flywheel_api_key in secrets/api-keys.yaml).
buildNpmPackage {
  pname = "flywheel-cli";
  version = "0.1.115";

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
