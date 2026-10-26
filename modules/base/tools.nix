{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # === Development Tools ===

    # Version control
    gh # GitHub CLI
    gitlab
    lazygit
    git-lfs
    git-crypt

    # Build tools
    cmake
    gnumake
    ninja
    meson
    pkg-config
    openmpi

    # Compilers & interpreters
    gcc
    # clang # Commented out to avoid conflict with gcc
    rustc
    cargo
    go
    nodejs_22
    python311

    # Language specific tools
    poetry
    pipenv
    virtualenv
    uv
    cargo-edit
    cargo-watch
    cargo-expand
    rustfmt
    clippy

    # === ML/AI Tools ===

    # Python ML packages (better managed via shell.nix per project)
    # but these are useful globally
    # python311Packages.ipython  # Commented out due to matplotlib dependency
    # Temporarily disabled due to build issues
    # python311Packages.jupyter
    # python311Packages.notebook
    # python311Packages.jupyterlab
    # python311Packages.numpy
    # python311Packages.pandas
    # python311Packages.matplotlib
    # python311Packages.seaborn
    # python311Packages.scikit-learn

    # Data tools
    jq # JSON processor

    # === Cloud & DevOps ===

    # Container tools
    docker
    docker-compose
    docker-buildx
    podman
    buildah
    skopeo
    dive # Docker image explorer

    # Kubernetes
    # kubectl # k3s includes kubectl, so we don't need standalone
    kubernetes-helm
    k9s # Terminal UI for k8s
    k3s
    kubectx

    # === Productivity Tools ===

    # Terminal multiplexer & utils
    tmux
    screen

    # File management
    ranger # Terminal file manager

    # Text processing
    sd # Modern sed
    grex # Regex builder
    choose # Modern cut

    # Network tools
    socat
    netcat
    iperf3
    bandwhich # Network utilization
    gping # Ping with graph

    # === Database Tools ===

    postgresql
    redis
    sqlite

    # === Security Tools ===

    # Network security
    nmap
    rustscan
    wireshark-cli
    tcpdump

    # === Documentation ===

    pandoc # Document converter
    graphviz # Graph visualization

    # === Media Tools ===

    ffmpeg

    # === Archive & Compression ===

    atool # Universal archive tool
    unar # Universal unarchiver

    # === Misc Useful Tools ===

    tldr # Simplified man pages

    entr # Run commands on file change
    watchexec # Similar to entr

    asciinema # Terminal recording
    termtosvg # Terminal to SVG

    # Fun stuff for screenshots
    silicon # Code screenshots
    pastel # Color manipulation

    powertop
    lm_sensors
    linuxPackages.turbostat
  ];

  # Language-specific configurations

  # Rust
  home.file.".cargo/config.toml".text = ''
    [build]
    rustc-wrapper = "${pkgs.sccache}/bin/sccache"

    [target.x86_64-unknown-linux-gnu]
    linker = "clang"
    rustflags = ["-C", "link-arg=-fuse-ld=${pkgs.mold}/bin/mold"]
  '';

  # Go
  programs.go = {
    enable = true;
    env = {
      GOPATH = ".local/share/go";
      GOBIN = ".local/bin";
    };
  };

  # Node.js global packages
  home.file.".npmrc".text = ''
    prefix=~/.local/share/npm
    cache=~/.cache/npm
    init-module=~/.config/npm/config/npm-init.js
  '';

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.local/share/npm/bin"
    "$HOME/.cargo/bin"
  ];
}
