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
    # Use the latest production driver
    # RTX 5090 requires the latest drivers
    package = config.boot.kernelPackages.nvidiaPackages.production;

    # Modesetting is required for Wayland
    modesetting.enable = true;

    # Power management (important for laptops, optional for desktops)
    powerManagement.enable = true;

    # Enable the NVIDIA settings menu
    nvidiaSettings = true;

    # Use the open kernel module (recommended for newer GPUs like RTX 5090)
    # This provides better Wayland support
    open = true;

    # Enable Dynamic Boost (if supported)
    dynamicBoost.enable = false; # Set to true if you want dynamic boost

    # Fine-grained power management
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

    # Enable framebuffer console
    "nvidia-drm.fbdev=1"

    # Disable GSP firmware (can help with some issues)
    # Uncomment if you experience problems
    # "nvidia.NVreg_EnableGpuFirmware=0"
  ];

  # Early KMS for NVIDIA
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
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

  environment.variables = {
    C_INCLUDE_PATH = "${pkgs.python311Full}/include/python3.11";
    CPLUS_INCLUDE_PATH = "${pkgs.python311Full}/include/python3.11";
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

    # AI development essentials
    python311
    python311Full
    gcc
    pkg-config
    uv
    git-lfs

    # CUDA development tools
    cudaPackages.cudatoolkit
    gcc
  ];
}
