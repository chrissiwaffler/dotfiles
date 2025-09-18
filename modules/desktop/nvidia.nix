{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable NVIDIA drivers - prioritize over integrated graphics
  services.xserver.videoDrivers = ["nvidia"];

  # Disable integrated AMD graphics
  boot.blacklistedKernelModules = ["amdgpu" "radeon"];

  hardware.nvidia = {
    # RTX 5090 with Blackwell architecture
    package = config.boot.kernelPackages.nvidiaPackages.latest;

    # Modesetting is required for Wayland
    modesetting.enable = true;

    # Power management - disable for immediate GPU access
    powerManagement.enable = false;

    # Enable the NVIDIA settings menu
    nvidiaSettings = true;

    # Use proprietary drivers for RTX 5090 (open source has NvKmsKapiDevice issues)
    # RTX 5090 Blackwell has issues with open source drivers
    open = true;

    # Enable Dynamic Boost (if supported)
    dynamicBoost.enable = false; # Set to true if you want dynamic boost

    # Fine-grained power management (disabled for desktop systems)
    powerManagement.finegrained = false;
  };

  # Graphics configuration with NVIDIA
  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    # Extra packages for NVIDIA
    extraPackages = with pkgs; [
      nvidia-vaapi-driver # VA-API implementation
      vaapiVdpau
      libvdpau-va-gl
    ];

    extraPackages32 = with pkgs.pkgsi686Linux; [
      nvidia-vaapi-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # Kernel parameters for NVIDIA
  boot.kernelParams = [
    # Enable DRM kernel mode setting
    "nvidia-drm.modeset=1"
    # Force PCIe mode
    "pcie_port_pm=off"
    # Disable ACPI for GPU
    "acpi_rev_override=1"
    # Enable MSI
    "nvidia.NVreg_EnableMSI=1"
    # Enable UEFI mode
    "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1"
  ];

  # Early KMS for NVIDIA - ensure modules are loaded at boot
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  # Ensure NVIDIA modules are available
  boot.extraModulePackages = [
    # Explizit den open path nehmen
    config.boot.kernelPackages.nvidia_x11_latest_open
  ];

  # Environment variables for NVIDIA + Wayland
  environment.sessionVariables = {
    # Force GBM backend
    GBM_BACKEND = "nvidia-drm";

    # OpenGL vendor
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Wayland compatibility
    LIBVA_DRIVER_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1"; # Required for NVIDIA

    # Enable VA-API on NVIDIA
    NVD_BACKEND = "direct";

    # XDG Session
    XDG_SESSION_TYPE = "wayland";

    # Electron apps fix
    NIXOS_OZONE_WL = "1";

    # Direct rendering for NVIDIA
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1"; # Enable VRR if monitor supports it

    # Performance tuning
    __GL_SHADER_DISK_CACHE = "1";
    __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";

    # CUDA environment for RTX 5090
    CUDA_HOME = "${pkgs.cudaPackages.cudatoolkit}";
    CUDA_ROOT = "${pkgs.cudaPackages.cudatoolkit}";
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    NVCC_PREPEND_FLAGS = "-ccbin ${pkgs.gcc}/bin/gcc";
    CUDA_CACHE_DISABLE = "0";
    TORCH_CUDA_ARCH_LIST = "12.0"; # RTX 5090 sm_120 capability

    # PyTorch optimizations
    PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";

    # Model cache location
    HF_HOME = "$HOME/.cache/huggingface";
  };

  # RTX 5090 support - append to LD_LIBRARY_PATH without conflicts
  environment.extraInit = ''
    export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib:/run/opengl-driver/lib:''${LD_LIBRARY_PATH:-}"
  '';

  # Enable nix-ld for PyTorch nightly compatibility
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      glibc
      cudaPackages.cudatoolkit
      cudaPackages.cudnn
      zlib
      openssl
    ];
  };

  # Fix Triton/vLLM ldconfig path issue
  environment.pathsToLink = ["/sbin"];

  # Create a simple ldconfig wrapper that handles the cache issue
  environment.etc."ldconfig-wrapper" = {
    text = ''
      #!/bin/sh
      # Wrapper for ldconfig that works with NixOS
      if [ "$1" = "-p" ]; then
        # For -p flag, just return empty (Triton will handle missing libraries gracefully)
        exit 0
      else
        # For other operations, call real ldconfig
        exec ${pkgs.glibc.bin}/bin/ldconfig "$@"
      fi
    '';
    mode = "0755";
  };

  # Create symlink to use our wrapper
  systemd.tmpfiles.rules = [
    "L+ /sbin/ldconfig - - - - /etc/ldconfig-wrapper"
  ];

  # Enable NVIDIA persistence daemon for headless GPU access
  systemd.services.nvidia-persistenced = {
    description = "NVIDIA Persistence Daemon";
    wantedBy = ["multi-user.target"];
    after = ["syslog.target"];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${config.boot.kernelPackages.nvidiaPackages.stable.bin}/bin/nvidia-persistenced --verbose";
      ExecStopPost = "${config.boot.kernelPackages.nvidiaPackages.stable.bin}/bin/nvidia-smi -pm 0 || true";
      Restart = "always";
    };
  };

  environment.variables = {
    C_INCLUDE_PATH = "${pkgs.python311}/include/python3.11";
    CPLUS_INCLUDE_PATH = "${pkgs.python311}/include/python3.11";
  };

  # Additional packages for NVIDIA utilities
  environment.systemPackages = with pkgs; [
    nvtopPackages.full # GPU monitoring
    nvidia-vaapi-driver
    egl-wayland
    libva-utils
    glxinfo
    vulkan-tools
    wayland-utils

    # NVIDIA tools for headless access
    config.boot.kernelPackages.nvidiaPackages.stable

    # Firmware for RTX 5090
    linux-firmware

    # AI development essentials
    python311
    gcc
    pkg-config
    uv
    git-lfs

    # CUDA development tools
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    cudaPackages.nccl
  ];
}
