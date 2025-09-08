{pkgs}:
pkgs.opencode.overrideAttrs (oldAttrs: rec {
  version = "0.6.5";
  src = pkgs.fetchFromGitHub {
    owner = "sst";
    repo = "opencode";
    tag = "v${version}";
    hash = "sha256-jw2S/PP/kjvK5tXdc4WcywHokmFIspFPLKO1oXT6jLA=";
    # nix will tell you the correct hash
    # run: nix-build -E 'with import <nixpkgs> {}; callPackage ./pkgs/opencode.nix {}'
    # and then update the sha256 hash
  };
})
