{
  config,
  lib,
  pkgs,
  ...
}: {
  # Machine Learning Development Environment
  
  environment.systemPackages = with pkgs; [
    # Container support for ML workflows
    docker
    docker-compose
    docker-buildx
    
    # Development tools
    gcc
    cmake
    git
    
    # Data processing
    jq
    csvkit
    
    # Performance monitoring
    btop
  ];
  
  # Docker configuration for ML containers
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };
  
  # NVIDIA container toolkit for GPU support
  hardware.nvidia-container-toolkit.enable = true;
  
  # Create ML development shell script
  environment.etc."ml-shell.nix" = {
    text = ''
      { pkgs ? import <nixpkgs> {} }:
      pkgs.mkShell {
        name = "ml-dev-shell";
        buildInputs = with pkgs; [
          cudatoolkit
          cudnn
          linuxPackages.nvidia_x11
          
          # Python with ML packages
          (python311.withPackages (ps: with ps; [
            torch
            tensorflow
            numpy
            pandas
            jupyter
            # matplotlib  # Commented out due to tkinter build issues
          ]))
          
          # Development tools
          gcc
          cmake
          git
        ];
        
        shellHook = '''
          echo "🤖 Machine Learning Development Environment"
          echo "CUDA Version: $(nvcc --version | grep release | awk '{print $6}')"
          echo "Python: $(python --version)"
          echo "PyTorch: $(python -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'Not available')"
          echo "TensorFlow: $(python -c 'import tensorflow; print(tensorflow.__version__)' 2>/dev/null || echo 'Not available')"
          echo ""
          echo "GPU Available: $(python -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null || echo 'Check failed')"
          
          export CUDA_PATH=${pkgs.cudatoolkit}
          export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib:$LD_LIBRARY_PATH
          export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
          export EXTRA_CCFLAGS="-I/usr/include"
        ''';
      }
    '';
  };
  
  # Jupyter configuration
  services.jupyter = {
    enable = false;  # Set to true if you want system-wide Jupyter
    # port = 8888;
    # password = ""; # Set a password hash here
    # kernels = {
    #   python3 = {
    #     displayName = "Python 3 ML";
    #     argv = [
    #       "${pythonML}/bin/python"
    #       "-m"
    #       "ipykernel_launcher"
    #       "-f"
    #       "{connection_file}"
    #     ];
    #   };
    # };
  };
  
  # System optimizations for ML workloads
  boot.kernel.sysctl = {
    # Increase shared memory for parallel processing
    "kernel.shmmax" = 68719476736;  # 64GB
    "kernel.shmall" = 16777216;     # 64GB / 4096
    
    # Optimize for compute workloads
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
  };
  
  # Environment variables for ML
  environment.sessionVariables = {
    # PyTorch - RTX 5090 support
    TORCH_CUDA_ARCH_LIST = "12.0";  # RTX 5090 sm_120 capability
    
    # TensorFlow
    TF_FORCE_GPU_ALLOW_GROWTH = "true";
    TF_CPP_MIN_LOG_LEVEL = "2";  # Reduce TF verbosity
    
    # CUDA
    CUDA_VISIBLE_DEVICES = "0";  # Default to first GPU
    
    # XLA optimization
    XLA_FLAGS = "--xla_gpu_cuda_data_dir=${pkgs.cudatoolkit}";
  };
  
  # Aliases for common ML tasks
  programs.bash.shellAliases = {
    gpu-status = "nvidia-smi";
    gpu-watch = "watch -n 1 nvidia-smi";
  };
}
