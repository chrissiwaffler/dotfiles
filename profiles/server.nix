{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./base.nix
  ];

  # server-specific packages (headless, no GUI)
  home.packages = with pkgs; [
    # python ML essentials
    python311
    python311Packages.pip
    python311Packages.virtualenv
    uv

    # container stuff
    docker
    docker-compose

    # monitoring
    nvtopPackages.full # GPU monitoring
    btop

    # network tools für remote work
    tmux
    mosh # better than ssh for unstable connections

    # dev tools die auf server sinn machen
    nodejs_22
    go

    # für benchmarks/profiling
    hyperfine
    perf-tools

    # missing build tools from standard build-essentials
    autoconf
    automake
    libtool
    m4
    patch
    flex
    bison
    clang
    llvm

    # dev headers
    zlib.dev
    openssl.dev
    libffi.dev
  ];
}
