# Overlay: flywheel CLI + agent skills, packaged from the pinned npm tarball
# (flake input "flywheel-skills"; see flake.nix for the bump procedure).
# The overlay is parameterized on the flake input because `pkgsFor` must close
# over it (flake inputs are not in scope inside a plain overlay import).
{flywheel-skills}: final: prev: {
  flywheel = final.callPackage ../pkgs/flywheel {inherit flywheel-skills;};
}
