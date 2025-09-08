{
  config,
  lib,
  pkgs,
  ...
}: {
  # Performance optimizations for desktop and ML workloads

  # CPU Governor and frequency scaling
  services.auto-cpufreq = {
    enable = true;
    settings = {
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };

  # Kernel parameters for performance
  boot.kernelParams = [
    # CPU optimizations
    # "mitigations=off" # Disable CPU vulnerability mitigations for max performance (security trade-off)
    # "nowatchdog" # Disable watchdog
    # "nmi_watchdog=0" # Disable NMI watchdog

    # Memory management
    "transparent_hugepage=always"

    # I/O optimizations
    "elevator=noop" # Use noop I/O scheduler for NVMe
  ];

  # Kernel sysctl optimizations
  boot.kernel.sysctl = {
    # Network optimizations
    "net.core.netdev_max_backlog" = 5000;
    "net.ipv4.tcp_congestion" = "bbr";
    "net.core.default_qdisc" = "cake";

    # Memory management
    # "vm.swappiness" = 10;
    # "vm.vfs_cache_pressure" = 50;
    # "vm.dirty_ratio" = 15;
    # "vm.dirty_background_ratio" = 5;
    # "vm.dirty_writeback_centisecs" = 1500;

    # Shared memory for ML workloads
    "kernel.shmmax" = 68719476736; # 64GB
    "kernel.shmall" = 16777216; # 64GB / 4096

    # File handles
    "fs.file-max" = 2097152;
    "fs.inotify.max_user_watches" = 524288;
  };

  # Nix build optimizations
  nix.settings = {
    # Parallel builds
    max-jobs = "auto";
    cores = 0; # Use all available cores

    # Build features
    system-features = [
      "nixos-test"
      "benchmark"
      "big-parallel"
      "kvm"
      "gccarch-native"
    ];
  };

  # Compiler optimizations
  nixpkgs.hostPlatform = {
    system = "x86_64-linux";
    gcc.arch = "native"; # Optimize for the specific CPU
    gcc.tune = "native";
  };

  # Storage optimizations
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # Nix store optimization
  nix.optimise = {
    automatic = true;
    dates = ["03:45"];
  };

  # ZRAM swap for better memory compression
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Disable unnecessary services
  services.xserver.updateDbusEnvironment = false;
  documentation.nixos.enable = false; # Disable if you don't need local NixOS manual

  # Performance monitoring tools
  environment.systemPackages = with pkgs; [
    # System monitoring
    htop
    btop
    iotop
    nethogs

    # CPU management
    cpufrequtils
    turbostat

    # Memory analysis
    smem
    earlyoom # Early OOM daemon

    # Disk I/O
    hdparm
    nvme-cli

    # Benchmarking
    sysbench
    stress-ng
    phoronix-test-suite
  ];

  # Early OOM killer to prevent system freezes
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
  };

  # Preload daemon for faster application startup
  services.preload = {
    enable = true;
  };
}
