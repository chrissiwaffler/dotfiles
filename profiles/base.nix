inputs: {
  config,
  pkgs,
  lib,
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
    stateVersion = "25.05";

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
    ];
  };

  nixpkgs.config.allowUnfree = true;

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
