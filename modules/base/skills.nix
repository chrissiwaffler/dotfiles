{
  lib,
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
in {
  home.file = lib.mapAttrs' (name: _:
    lib.nameValuePair "agents/skills/${name}" {
      source = skillsRoot + "/${name}";
      recursive = true;
    })
  skillDirs;
}
