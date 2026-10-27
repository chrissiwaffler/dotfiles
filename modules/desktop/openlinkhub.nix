# Fan/pump control for the two Corsair iCUE LINK System Hubs via OpenLinkHub
# (https://github.com/jurkovic-nikola/OpenLinkHub). Without it the hubs run
# fixed default speeds that ignore the CPU temperature.
#
#   - Hub with the TITAN 360 AIO (pump + radiator fans): "cpuCurve", driven by
#     the CPU temperature (k10temp Tctl).
#   - Other hub (case fans): "caseCurve", driven by max(CPU, GPU). In the lium
#     specialisation the RTX 5090 belongs to the VM, so the host cannot read
#     its temperature; the case fans get a higher floor there instead, since a
#     rented GPU dumps up to 575 W into the case. The GPU's own fans are always
#     controlled by its firmware/driver, independent of this.
#   - Lighting on both hubs is switched off (they are no longer handled by
#     OpenRGB, see rgb-off.nix).
#
# Web UI (live RPM/temperatures, curve editing) on localhost only:
#   ssh -L 27003:localhost:27003 desktop   ->  http://localhost:27003
# Curves are rewritten from this file on every start; edit them here.
{
  config,
  lib,
  pkgs,
  ...
}: let
  pkg = pkgs.openlinkhub;
  stateDir = "/var/lib/openlinkhub";
  port = 27003;
  lium = config.services.lium-node.active;

  settings = {
    debug = false;
    listenPort = port;
    listenAddress = "127.0.0.1";
    cpuSensorChip = "k10temp";
    manual = false;
    frontend = true;
    metrics = false;
    # RAM lighting stays with OpenRGB.
    memory = false;
    memorySmBus = "i2c-0";
    memoryType = 5;
    exclude = [];
    decodeMemorySku = false;
    memorySku = "";
    resumeDelay = 15000;
    logLevel = "info";
    logFile = "";
    enhancementKits = [];
    temperatureOffset = 0;
    amdGpuIndex = 0;
    amdsmiPath = "";
    checkDevicePermission = true;
    cpuTempFile = "";
    graphProfiles = true;
    ramTempViaHwmon = true;
    nvidiaGpuIndex = [0];
    defaultNvidiaGPU = 0;
    openRGBPort = 6743;
    enableOpenRGBTargetServer = false;
  };

  # Sensor ids from OpenLinkHub src/temperatures: 0 = CPU, 5 = max(CPU, GPU).
  # Points are {t = °C; fans = %; pump = %}, linearly interpolated.
  mkProfile = sensor: points: {
    inherit sensor;
    zeroRpm = false;
    linear = true;
    points = {
      "0" =
        map (p: {
          x = p.t;
          y = p.pump;
        })
        points;
      "1" =
        map (p: {
          x = p.t;
          y = p.fans;
        })
        points;
    };
    # Step fallback used when graph profiles are disabled.
    profiles =
      lib.imap1 (i: p: {
        id = i;
        min = p.t;
        max =
          if i < builtins.length points
          then (builtins.elemAt points i).t
          else 200;
        mode = 0;
        inherit (p) fans pump;
      })
      points;
    device = "";
    hwmonDevice = "";
    temperatureInputId = "";
    channelId = 0;
    gpuIndex = 0;
    sensorString = "";
    Hidden = false;
  };

  # 9950X3D: ~45 °C idle, throttles at 95 °C. Full speed from 88 °C.
  cpuCurve = mkProfile 0 [
    {
      t = 0;
      fans = 30;
      pump = 60;
    }
    {
      t = 50;
      fans = 35;
      pump = 60;
    }
    {
      t = 60;
      fans = 45;
      pump = 70;
    }
    {
      t = 70;
      fans = 60;
      pump = 80;
    }
    {
      t = 80;
      fans = 80;
      pump = 90;
    }
    {
      t = 88;
      fans = 100;
      pump = 100;
    }
  ];

  caseCurve = mkProfile 5 (
    if lium
    then [
      {
        t = 0;
        fans = 55;
        pump = 70;
      }
      {
        t = 60;
        fans = 60;
        pump = 70;
      }
      {
        t = 70;
        fans = 70;
        pump = 80;
      }
      {
        t = 80;
        fans = 85;
        pump = 90;
      }
      {
        t = 88;
        fans = 100;
        pump = 100;
      }
    ]
    else [
      {
        t = 0;
        fans = 30;
        pump = 60;
      }
      {
        t = 50;
        fans = 35;
        pump = 60;
      }
      {
        t = 60;
        fans = 45;
        pump = 70;
      }
      {
        t = 70;
        fans = 60;
        pump = 80;
      }
      {
        t = 80;
        fans = 80;
        pump = 90;
      }
      {
        t = 88;
        fans = 100;
        pump = 100;
      }
    ]
  );

  json = name: value: pkgs.writeText name (builtins.toJSON value);

  udevRules = pkgs.runCommand "openlinkhub-udev-rules" {} ''
    install -Dm644 ${pkg.src}/99-openlinkhub.rules $out/lib/udev/rules.d/99-openlinkhub.rules
  '';

  # OpenLinkHub reads config.json, web/, static/ and database/ from its
  # working directory. web/ and static/ come straight from the source;
  # database/ must be writable (device profiles are stored there).
  setup = pkgs.writeShellScript "openlinkhub-setup" ''
    set -eu
    cd ${stateDir}
    ln -sfn ${pkg.src}/web web
    ln -sfn ${pkg.src}/static static
    if [ ! -d database ]; then
      cp -r --no-preserve=mode ${pkg.src}/database database
    fi
    mkdir -p database/temperatures database/profiles
    install -m 0644 ${json "config.json" settings} config.json
    install -m 0644 ${json "cpuCurve.json" cpuCurve} database/temperatures/cpuCurve.json
    install -m 0644 ${json "caseCurve.json" caseCurve} database/temperatures/caseCurve.json
  '';

  # Assigns the curves and turns the lighting off via the local API. Runs
  # after every OpenLinkHub start; idempotent.
  apply = pkgs.writeShellApplication {
    name = "openlinkhub-apply";
    runtimeInputs = [pkgs.curl pkgs.jq];
    text = ''
      api=http://127.0.0.1:${toString port}/api
      post() {
        curl -sf -X POST -H 'Content-Type: application/json' -d "$2" "$api/$1"
      }

      # Wait for the API and for both hubs to be enumerated (skipping hidden
      # pseudo-devices such as "cluster").
      serials=""
      for _ in $(seq 60); do
        serials=$(curl -sf "$api/devices/" | jq -r '.devices // {} | to_entries[] | select(.value.Hidden != true) | .key' 2>/dev/null || true)
        [ "$(wc -w <<<"$serials")" -ge 2 ] && break
        sleep 2
      done
      if [ -z "$serials" ]; then
        echo "OpenLinkHub reports no devices" >&2
        exit 1
      fi

      for s in $serials; do
        dev=$(curl -sf "$api/devices/$s")
        if jq -e '.device.aio == true or ([.device.devices[]?.name // ""] | any(test("TITAN|H1[0-9]{2}i"; "i")))' <<<"$dev" >/dev/null; then
          profile=cpuCurve
        else
          profile=caseCurve
        fi
        speed=$(post speed "{\"deviceId\":\"$s\",\"channelId\":-1,\"profile\":\"$profile\"}")
        color=$(post color "{\"deviceId\":\"$s\",\"channelId\":-1,\"profile\":\"off\"}")
        echo "$s ($(jq -r '.device.product // "?"' <<<"$dev")): speed=$profile -> $(jq -r '.message // .status' <<<"$speed"), rgb=off -> $(jq -r '.message // .status' <<<"$color")"
      done
    '';
  };
in {
  users.users.openlinkhub = {
    isSystemUser = true;
    group = "openlinkhub";
    description = "OpenLinkHub fan/RGB controller";
  };
  users.groups.openlinkhub = {};

  # Hands the Corsair USB/hidraw nodes to the openlinkhub user.
  services.udev.packages = [udevRules];

  systemd.services.openlinkhub = {
    description = "OpenLinkHub (Corsair iCUE LINK fan/pump control)";
    wantedBy = ["multi-user.target"];
    after = ["systemd-udev-settle.service"];
    # nvidia-smi for the GPU temperature (caseCurve); absent in lium mode.
    path = lib.optional (!lium) config.hardware.nvidia.package.bin;
    serviceConfig = {
      User = "openlinkhub";
      Group = "openlinkhub";
      StateDirectory = "openlinkhub";
      WorkingDirectory = stateDir;
      ExecStartPre = setup;
      ExecStart = "${pkg}/bin/OpenLinkHub";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  systemd.services.openlinkhub-apply = {
    description = "Apply OpenLinkHub fan curves and lighting";
    after = ["openlinkhub.service"];
    bindsTo = ["openlinkhub.service"];
    wantedBy = ["openlinkhub.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${apply}/bin/openlinkhub-apply";
    };
  };
}
