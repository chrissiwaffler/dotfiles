{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./base.nix
    ../modules/desktop/hyprland.nix
    ../modules/desktop/tools.nix
    ../modules/desktop/config.nix
  ];

  # Enable desktop-specific services
  services = {
    # Enable GPG agent for desktop
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentry.package = pkgs.pinentry-gnome3;
    };

    # Enable syncthing for file sync
    syncthing = {
      enable = true;
      extraOptions = ["--allow-newer-config"];
    };
  };

  # Desktop-specific packages
  home.packages = with pkgs; [
    # Browsers
    firefox
    chromium

    # Communication
    discord
    slack
    signal-desktop

    # Media
    mpv
    spotify
    obs-studio

    # Graphics
    gimp
    inkscape

    # Office
    libreoffice
    obsidian

    # Development (GUI tools)
    vscode
    insomnia
    dbeaver-bin

    # AI coding assistant
    inputs.self.packages.${pkgs.system}.opencode

    # System tools
    gnome-disk-utility
    seahorse

    # Fonts
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.hack
    font-awesome
    noto-fonts
    noto-fonts-emoji
    liberation_ttf

    openrgb
    liquidctl
  ];

  # Font configuration
  fonts.fontconfig.enable = true;

  # XDG desktop integration
  xdg = {
    enable = true;
    mime.enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/about" = "firefox.desktop";
        "x-scheme-handler/unknown" = "firefox.desktop";
        "application/pdf" = "org.gnome.Evince.desktop";
        "image/png" = "org.gnome.eog.desktop";
        "image/jpeg" = "org.gnome.eog.desktop";
        "image/gif" = "org.gnome.eog.desktop";
      };
    };
  };

  # GTK theme configuration
  gtk = {
    enable = true;
    theme = {
      name = "Arc-Dark";
      package = pkgs.arc-theme;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # Qt theme configuration
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "gtk2";
  };

  # Enable dconf for GTK settings persistence
  dconf.enable = true;
}
