{
  config,
  pkgs,
  lib,
  inputs,
  stateVersion,
  ...
}: {
  imports = [
    ../modules/base/neovim.nix
    ../modules/base/shell.nix
    ../modules/base/tools.nix
  ];

  # let home-manager manage itself
  programs.home-manager.enable = true;

  home = {
    username = lib.mkDefault "chrissi";
    homeDirectory = lib.mkDefault (
      if pkgs.stdenv.isDarwin
      then "/Users/chrissi"
      else "/home/chrissi"
    );
    stateVersion = lib.mkDefault stateVersion;

    # env variables
    sessionVariables = {
      EDITOR = "nvim";
    };

    # basic packages that should always be available
    packages = with pkgs; [
      # core utils
      coreutils
      findutils
      gnugrep
      gnused
      gawk

      # Archive tools
      unzip
      zip
      gzip
      bzip2
      xz
      p7zip

      # System monitoring
      htop
      btop
      iotop
      iftop
      ncdu
      duf

      # Modern unix
      bat
      eza
      fd
      ripgrep
      fzf
      zoxide
      delta
      dust
      procs
      bottom

      # Networking
      curl
      wget
      httpie
      mtr
      nmap
      dogdns

      # Fun stuff
      neofetch
      figlet
      lolcat
      cowsay
      sl

      # Python ML essentials
      python311
      python311Packages.pip
      uv

      # Container stuff
      docker
      docker-compose

      # GPU monitoring
      nvtopPackages.full

      # Network tools for remote work
      tmux
      mosh # better than ssh for unstable connections

      # Additional dev tools
      nodejs_22
      go

      # Benchmarks/profiling
      hyperfine
      perf-tools

      # Build tools from standard build-essentials
      autoconf
      automake
      libtool
      m4
      patch
      flex
      bison
      llvm

      # Dev headers
      zlib.dev
      openssl.dev
      libffi.dev

      # AI coding assistant
      inputs.opencode.packages.${pkgs.system}.default
    ];
  };

  # XDG base directories
  xdg = {
    enable = true;
    configHome = "${config.home.homeDirectory}/.config";
    cacheHome = "${config.home.homeDirectory}/.cache";
    dataHome = "${config.home.homeDirectory}/.local/share";
    stateHome = "${config.home.homeDirectory}/.local/state";
  };

  # Pass inputs to all module imports
  _module.args = {inherit inputs;};
}
