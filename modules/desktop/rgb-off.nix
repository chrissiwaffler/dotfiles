{
  config,
  pkgs,
  ...
}: let
  # Connects to the OpenRGB SDK server and blanks every device: devices with an
  # "Off" mode get it, the rest (e.g. Corsair RAM) get direct black.
  rgbOff =
    pkgs.writers.writePython3Bin "rgb-off" {
      libraries = [pkgs.python3Packages.openrgb-python];
    } ''
      import sys
      import time

      from openrgb import OpenRGBClient
      from openrgb.utils import RGBColor

      PORT = ${toString config.services.hardware.openrgb.server.port}

      for _ in range(60):
          try:
              client = OpenRGBClient("127.0.0.1", PORT, "rgb-off")
              break
          except ConnectionRefusedError:
              time.sleep(1)
      else:
          sys.exit("OpenRGB server not reachable")

      # The server accepts connections before detection is done; wait until the
      # device count is non-zero and stable.
      prev = -1
      for _ in range(20):
          client.update()
          if len(client.devices) > 0 and len(client.devices) == prev:
              break
          prev = len(client.devices)
          time.sleep(3)

      for dev in client.devices:
          modes = {m.name.lower(): m for m in dev.modes}
          if "off" in modes:
              dev.set_mode(modes["off"])
              print(f"{dev.name}: off")
          else:
              if "direct" in modes:
                  dev.set_mode(modes["direct"])
              dev.set_color(RGBColor(0, 0, 0))
              print(f"{dev.name}: black")
    '';
in {
  # The OpenRGB server installs the udev rules + i2c modules and handles the
  # RAM and GPU lighting. The iCUE LINK hubs are owned by OpenLinkHub
  # (openlinkhub.nix, fan curves + lighting off), so OpenRGB's detector for
  # them is disabled; two programs driving the same hub would fight.
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  systemd.services.openrgb.preStart = ''
    cfg=/var/lib/OpenRGB/OpenRGB.json
    [ -s "$cfg" ] || echo '{}' > "$cfg"
    ${pkgs.jq}/bin/jq '.Detectors.detectors["Corsair iCUE Link System Hub"] = false' "$cfg" > "$cfg.tmp"
    mv "$cfg.tmp" "$cfg"
  '';

  systemd.services.rgb-off = {
    description = "Turn off all RGB lighting via OpenRGB";
    after = ["openrgb.service" "suspend.target" "hibernate.target" "hybrid-sleep.target"];
    requires = ["openrgb.service"];
    # Re-run after resume, devices may reset their lighting on wake.
    wantedBy = ["multi-user.target" "suspend.target" "hibernate.target" "hybrid-sleep.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${rgbOff}/bin/rgb-off";
    };
  };
}
