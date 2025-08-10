{
  config,
  lib,
  pkgs,
  ...
}: {
  # NVIDIA RTX 5090 GPU Configuration
  
  # Allow unfree packages (NVIDIA drivers are proprietary)
  nixpkgs.config.allowUnfree = true;
  
  # Enable OpenGL
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      nvidia-vaapi-driver
    ];
  };
  
  # Load NVIDIA driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];
  
  # NVIDIA configuration
  hardware.nvidia = {
    # Modesetting is required for Wayland compositors
    modesetting.enable = true;
    
    # Power management (can cause sleep/suspend issues)
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    
    # Use open kernel module (recommended for Turing and newer)
    open = true;
    
    # Enable the nvidia-settings GUI tool
    nvidiaSettings = true;
    
    # Select the appropriate driver version for RTX 5090
    # Note: You may need to use beta/production drivers for newest GPUs
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # Alternative for newer GPUs:
    # package = config.boot.kernelPackages.nvidiaPackages.production;
    # package = config.boot.kernelPackages.nvidiaPackages.beta;
  };
  
  # Enable CUDA support globally
  nixpkgs.config.cudaSupport = true;
  
  # Environment variables for NVIDIA
  environment.sessionVariables = {
    # Force NVIDIA GPU for rendering
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1"; # Needed for some Wayland compositors
    NIXOS_OZONE_WL = "1"; # Hint for Electron apps to use Wayland
    
    # CUDA environment
    CUDA_CACHE_PATH = "$HOME/.cache/cuda";
  };
  
  # Additional kernel modules for NVIDIA
  boot.initrd.kernelModules = [ "nvidia" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];
  
  # Kernel parameters for better NVIDIA support
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];
  
  # System packages for GPU monitoring and management
  environment.systemPackages = with pkgs; [
    nvtop          # GPU process monitoring
    nvidia-smi     # NVIDIA System Management Interface
    cudatoolkit    # CUDA toolkit
    cudnn          # CUDA Deep Neural Network library
  ];
}
