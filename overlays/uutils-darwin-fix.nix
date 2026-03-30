# Overlay to fix uutils-coreutils build on Darwin
# Issue: manpage generation tries to write to nix store during build
# Fix: Disable manpage generation for Darwin builds
final: prev: {
  uutils-coreutils =
    if prev.stdenv.isDarwin
    then
      prev.uutils-coreutils.overrideAttrs (oldAttrs: {
        # Skip manpage generation on Darwin
        postInstall =
          (oldAttrs.postInstall or "")
          + ''
            # Remove any broken manpage installation attempts
            rm -rf $out/share/man || true
          '';
        # Disable manpage build in make flags
        makeFlags = (oldAttrs.makeFlags or []) ++ ["PREFIX=$out"];
      })
    else prev.uutils-coreutils;
}
