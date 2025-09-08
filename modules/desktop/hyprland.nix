{
  config,
  lib,
  pkgs,
  ...
}: {
  # Session variables for Wayland + NVIDIA
  home.sessionVariables = {
    # Wayland session
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    
    # NVIDIA-specific for Hyprland
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";  # Required for NVIDIA
    WLR_DRM_NO_ATOMIC = "1";  # May help with some NVIDIA issues
    
    # Electron/Chrome apps
    NIXOS_OZONE_WL = "1";
    
    # VA-API
    NVD_BACKEND = "direct";
    
    # Qt
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
  };
  
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd.enable = true;  # Enable systemd integration
    
    settings = {
      # Monitor configuration (adjust to your setup)
      monitor = ",preferred,auto,1";
      
      # NVIDIA-specific settings
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "WLR_NO_HARDWARE_CURSORS,1"
      ];
      
      # Misc settings for NVIDIA
      misc = {
        #no_direct_scanout = true;  # May help with fullscreen issues on NVIDIA
        vrr = 1;  # Variable refresh rate (if your monitor supports it)
      };
      
      # Execute at launch
      exec-once = [
        "${pkgs.waybar}/bin/waybar"
        "${pkgs.dunst}/bin/dunst"
        "${pkgs.swww}/bin/swww init"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      ];
      
      # Input configuration
      input = {
        kb_layout = "de";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
        };
        sensitivity = 0;
      };
      
      # General settings
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
      };
      
      # Decoration
      decoration = {
        rounding = 10;
        
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
        
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
          color_inactive = "rgba(1a1a1a99)";
        };
      };
      
      # Animations
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };
      
      # Dwindle layout
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };
      
      # Master layout
      master = {
        new_status = "master";
        new_on_top = true;
      };
      
      # Window rules
      windowrulev2 = [
        "opacity 0.9 0.9,class:^(kitty)$"
        "opacity 0.9 0.9,class:^(Alacritty)$"
      ];
      
      # Mod key (Super key)
      "$mod" = "SUPER";
      
      # Key bindings
      bind = [
        # Program launchers
        "$mod, Return, exec, ${pkgs.kitty}/bin/kitty"
        "$mod, D, exec, ${pkgs.rofi-wayland}/bin/rofi -show drun"
        "$mod, B, exec, firefox"
        "$mod, E, exec, ${pkgs.nautilus}/bin/nautilus"
        
        # Window management
        "$mod, Q, killactive,"
        "$mod, F, fullscreen,"
        "$mod, Space, togglefloating,"
        "$mod, P, pseudo,"
        "$mod, J, togglesplit,"
        
        # Focus movement
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"
        
        # Window movement
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
        "$mod SHIFT, H, movewindow, l"
        "$mod SHIFT, L, movewindow, r"
        "$mod SHIFT, K, movewindow, u"
        "$mod SHIFT, J, movewindow, d"
        
        # Workspace switching
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"
        
        # Move window to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"
        
        # Special workspace (scratchpad)
        "$mod, S, togglespecialworkspace"
        "$mod SHIFT, S, movetoworkspace, special"
        
        # Scroll through existing workspaces
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
        
        # System controls
        "$mod SHIFT, M, exit,"
        "$mod SHIFT, R, exec, hyprctl reload"
      ];
      
      # Mouse bindings
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };
  
  # Install necessary packages for Hyprland
  home.packages = with pkgs; [
    # Terminal
    kitty
    
    # Application launcher
    rofi-wayland
    
    # Status bar
    waybar
    
    # Notification daemon
    dunst
    
    # Wallpaper
    swww
    
    # Screenshot tool
    grim
    slurp
    
    # Clipboard manager
    wl-clipboard
    
    # Authentication agent
    polkit_gnome
    
    # File manager
    nautilus
    
    # System utilities
    pavucontrol
    brightnessctl
    playerctl
  ];
  
  # Waybar configuration
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        
        modules-left = ["hyprland/workspaces" "hyprland/window"];
        modules-center = ["clock"];
        modules-right = ["pulseaudio" "network" "cpu" "memory" "battery" "tray"];
        
        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
        };
        
        clock = {
          format = "{:%Y-%m-%d %H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        
        cpu = {
          format = "CPU {usage}%";
          tooltip = false;
        };
        
        memory = {
          format = "MEM {}%";
        };
        
        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "⚡ {capacity}%";
          format-plugged = "🔌 {capacity}%";
          format-icons = ["🪫" "🔋" "🔋" "🔋" "🔋"];
        };
        
        network = {
          format-wifi = "📶 {signalStrength}%";
          format-ethernet = "🌐 {ipaddr}";
          format-disconnected = "❌ Disconnected";
          tooltip-format = "{ifname}: {ipaddr}";
        };
        
        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "";
          format-icons = {
            default = ["" "" ""];
          };
          on-click = "pavucontrol";
        };
        
        tray = {
          spacing = 10;
        };
      };
    };
    
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
      }
      
      window#waybar {
        background-color: rgba(43, 48, 59, 0.8);
        color: #ffffff;
        transition-property: background-color;
        transition-duration: .5s;
      }
      
      #workspaces button {
        padding: 0 5px;
        background-color: transparent;
        color: #ffffff;
        border-radius: 6px;
      }
      
      #workspaces button.active {
        background-color: #64727D;
      }
      
      #clock,
      #battery,
      #cpu,
      #memory,
      #network,
      #pulseaudio,
      #tray {
        padding: 0 10px;
        margin: 0 4px;
        color: #ffffff;
      }
      
      #battery.charging {
        color: #26A65B;
      }
      
      #battery.warning:not(.charging) {
        color: #ffbe61;
      }
      
      #battery.critical:not(.charging) {
        color: #f53c3c;
      }
    '';
  };
  
  # Rofi configuration
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    theme = "Arc-Dark";
  };
  
  # Enable kitty terminal
  programs.kitty = {
    enable = true;
    # themeFile = "tokyo_night";  # Commented out - theme not available in kitty-themes package
    settings = {
      font_family = "JetBrainsMono Nerd Font";
      font_size = 12;
      background_opacity = "0.9";
      window_padding_width = 10;
    };
  };
}
