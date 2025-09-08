{
  config,
  lib,
  pkgs,
  ...
}: let
  # Model configuration
  modelName = "Qwen/Qwen3-Coder-30B-A3B-Instruct";
  modelCacheDir = "/var/lib/llm-models";
  vllmDataDir = "/var/lib/vllm";

  # Performance configuration - maximize resource usage
  gpuMemoryUtilization = "0.98"; # Use 98% of VRAM (31.36GB of 32GB)
  tensorParallelSize = "1"; # Single GPU
  maxModelLen = "131072"; # 128K context (adjust based on needs)
  maxNumSeqs = "512"; # Maximum concurrent sequences
  maxNumBatchedTokens = "65536"; # Large batch size for throughput

  # Python environment with vLLM and dependencies
  pythonEnv = pkgs.python311.withPackages (ps:
    with ps; [
      pip
      numpy
      torch
      transformers
      sentencepiece
      protobuf
      pydantic
      fastapi
      uvicorn
      ray
      aiohttp
      prometheus-client
      psutil
      gpustat
    ]);

  # vLLM installation script
  # vllmSetupScript = pkgs.writeScriptBin "setup-vllm" ''
  #   #!${pkgs.bash}/bin/bash
  #   set -e
  #
  #   echo "Setting up vLLM environment..."
  #
  #   # Create virtual environment if it doesn't exist
  #   if [ ! -d "${vllmDataDir}/venv" ]; then
  #     ${pythonEnv}/bin/python -m venv ${vllmDataDir}/venv
  #   fi
  #
  #   # Activate and install/upgrade vLLM
  #   source ${vllmDataDir}/venv/bin/activate
  #   pip install --upgrade pip setuptools wheel
  #   pip install --upgrade vllm>=0.6.0
  #   pip install --upgrade flash-attn
  #   pip install --upgrade xformers
  #   pip install --upgrade bitsandbytes
  #
  #   echo "vLLM setup complete!"
  # '';
  #
  # # Main server script with aggressive optimization
  # vllmServerScript = pkgs.writeScriptBin "vllm-server" ''
  #   #!${pkgs.bash}/bin/bash
  #   set -e
  #
  #   # Performance tuning environment variables
  #   export CUDA_VISIBLE_DEVICES=0
  #   export CUDA_LAUNCH_BLOCKING=0
  #   export TORCH_CUDA_ARCH_LIST="8.9;9.0"  # RTX 5090 architecture
  #   export CUDA_MODULE_LOADING=LAZY
  #   export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,roundup_power2_divisions:16"
  #
  #   # NCCL optimizations (for potential multi-GPU future)
  #   export NCCL_P2P_DISABLE=0
  #   export NCCL_SHM_DISABLE=0
  #   export NCCL_IBEXT_DISABLE=0
  #
  #   # vLLM specific optimizations
  #   export VLLM_ATTENTION_BACKEND=FLASH_ATTN
  #   export VLLM_USE_TRITON_FLASH_ATTN=1
  #   export VLLM_ENABLE_CUDA_GRAPH=1
  #   export VLLM_USE_V2_BLOCK_MANAGER=1
  #   export VLLM_WORKER_MULTIPROC_METHOD=spawn
  #
  #   # CPU optimizations
  #   export OMP_NUM_THREADS=${toString config.nix.maxJobs}
  #   export MKL_NUM_THREADS=${toString config.nix.maxJobs}
  #   export NUMEXPR_NUM_THREADS=${toString config.nix.maxJobs}
  #
  #   # Model cache
  #   export HF_HOME="${modelCacheDir}"
  #   export TRANSFORMERS_CACHE="${modelCacheDir}/transformers"
  #   export HF_DATASETS_CACHE="${modelCacheDir}/datasets"
  #
  #   # Activate virtual environment
  #   source ${vllmDataDir}/venv/bin/activate
  #
  #   # Start vLLM with maximum performance settings
  #   exec python -m vllm.entrypoints.openai.api_server \
  #     --model "${modelName}" \
  #     --host 0.0.0.0 \
  #     --port 8000 \
  #     --gpu-memory-utilization ${gpuMemoryUtilization} \
  #     --max-model-len ${maxModelLen} \
  #     --max-num-seqs ${maxNumSeqs} \
  #     --max-num-batched-tokens ${maxNumBatchedTokens} \
  #     --tensor-parallel-size ${tensorParallelSize} \
  #     --dtype auto \
  #     --kv-cache-dtype auto \
  #     --enable-prefix-caching \
  #     --enable-chunked-prefill \
  #     --max-parallel-loading-workers 8 \
  #     --block-size 32 \
  #     --swap-space 8 \
  #     --gpu-memory-utilization ${gpuMemoryUtilization} \
  #     --enforce-eager \
  #     --enable-lora \
  #     --max-lora-rank 64 \
  #     --max-cpu-loras 8 \
  #     --disable-log-requests \
  #     --uvloop \
  #     --served-model-name "qwen3-coder" \
  #     --chat-template "${modelCacheDir}/chat_template.jinja" \
  #     --response-role "assistant" \
  #     --ssl-keyfile "" \
  #     --ssl-certfile "" \
  #     --root-path "" \
  #     --middleware []
  # '';

  # Health check script
  healthCheckScript = pkgs.writeScriptBin "vllm-health" ''
    #!${pkgs.bash}/bin/bash
    curl -f http://localhost:8000/health || exit 1
  '';

  # Performance monitoring script
  monitorScript = pkgs.writeScriptBin "vllm-monitor" ''
    #!${pkgs.bash}/bin/bash
    while true; do
      echo "=== vLLM Performance Monitor ==="
      echo "Time: $(date)"

      # GPU stats
      nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.free,temperature.gpu,power.draw --format=csv,noheader

      # Process stats
      ps aux | grep vllm | head -1

      # API stats
      curl -s http://localhost:8000/metrics 2>/dev/null | grep -E "vllm_"

      echo "================================"
      sleep 5
    done
  '';
in {
  # CUDA and GPU support
  # hardware.nvidia = {
  #   modesetting.enable = true;
  #   # powerManagement.enable = false; # Disable power management for max performance
  #   powerManagement.finegrained = false;
  # open = false; # Use proprietary drivers for best performance
  #   nvidiaSettings = true;
  #   package = config.boot.kernelPackages.nvidiaPackages.stable;
  # };

  # Enable CUDA support
  nixpkgs.config = {
    allowUnfree = true;
    cudaSupport = true;
    # RTX 5090 requires sm_120 capability
    cudaCapabilities = ["12.0"];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    pythonEnv
    # vllmSetupScript
    # vllmServerScript
    healthCheckScript
    monitorScript
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    cudaPackages.cutensor
    cudaPackages.nccl
    cudaPackages.tensorrt
    nvidia-docker
    # nvtop
    gpustat
    htop
    iotop
    nethogs
    jq
    curl
    git
  ];

  # Create necessary directories
  systemd.tmpfiles.rules = [
    "d ${modelCacheDir} 0755 vllm vllm -"
    "d ${vllmDataDir} 0755 vllm vllm -"
    "d /var/log/vllm 0755 vllm vllm -"
  ];

  # Create vllm user and group
  users.users.vllm = {
    isSystemUser = true;
    group = "vllm";
    home = vllmDataDir;
    createHome = true;
    shell = pkgs.bash;
    extraGroups = ["video" "render" "networkmanager"];
  };

  users.groups.vllm = {};

  # Main vLLM service
  systemd.services.vllm-server = {
    description = "vLLM Qwen3-Coder High-Performance Inference Server";
    after = ["network.target" "nvidia-persistenced.service"];
    wants = ["nvidia-persistenced.service"];
    wantedBy = ["multi-user.target"];

    # Service configuration
    serviceConfig = {
      Type = "simple";
      User = "vllm";
      Group = "vllm";
      WorkingDirectory = vllmDataDir;

      # Resource limits - maximize everything
      LimitNOFILE = 1048576;
      LimitNPROC = 1048576;
      LimitCORE = "infinity";
      LimitMEMLOCK = "infinity";
      TasksMax = "infinity";

      # CPU affinity - use all cores
      CPUWeight = 10000;
      CPUQuota = "";
      AllowedCPUs = "";

      # Memory settings
      MemoryMax = "infinity";
      MemorySwapMax = "infinity";

      # IO settings
      IOWeight = 10000;

      # Nice level for high priority
      Nice = -20;

      # Restart policy
      Restart = "always";
      RestartSec = 10;
      StartLimitInterval = 60;
      StartLimitBurst = 5;

      # Timeouts
      TimeoutStartSec = 600; # Model loading can take time
      TimeoutStopSec = 30;

      # Security settings (minimal restrictions for max performance)
      PrivateTmp = false;
      ProtectSystem = false;
      ProtectHome = false;
      NoNewPrivileges = false;

      # Environment
      Environment = [
        "PATH=/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
        "PYTHONUNBUFFERED=1"
        "CUDA_VISIBLE_DEVICES=0"
        "HF_HOME=${modelCacheDir}"
      ];

      # Execute
      # ExecStartPre = "${vllmSetupScript}/bin/setup-vllm";
      # ExecStart = "${vllmServerScript}/bin/vllm-server";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";

      # Logging
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };

    # Unit configuration
    unitConfig = {
      RequiresMountsFor = [modelCacheDir vllmDataDir];
      ConditionPathExists = "/dev/nvidia0";
    };
  };

  # Model downloader service (runs once)
  systemd.services.vllm-model-download = {
    description = "Download Qwen3-Coder model";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    before = ["vllm-server.service"];
    requiredBy = ["vllm-server.service"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "vllm";
      Group = "vllm";
      WorkingDirectory = vllmDataDir;

      Environment = [
        "HF_HOME=${modelCacheDir}"
        "TRANSFORMERS_CACHE=${modelCacheDir}/transformers"
      ];

      ExecStart = pkgs.writeScript "download-model" ''
                #!${pkgs.bash}/bin/bash
                set -e

                if [ ! -d "${modelCacheDir}/models--Qwen--Qwen3-Coder-30B-A3B-Instruct" ]; then
                  echo "Downloading Qwen3-Coder model..."
                  ${pythonEnv}/bin/python -c "
        from transformers import AutoTokenizer, AutoModelForCausalLM
        import torch

        print('Downloading model: ${modelName}')
        tokenizer = AutoTokenizer.from_pretrained('${modelName}', trust_remote_code=True)
        model = AutoModelForCausalLM.from_pretrained(
            '${modelName}',
            torch_dtype=torch.float16,
            trust_remote_code=True,
            low_cpu_mem_usage=True
        )
        print('Model download complete!')
                  "
                else
                  echo "Model already exists, skipping download."
                fi

                # Create chat template
                cat > ${modelCacheDir}/chat_template.jinja << 'EOF'
        {% for message in messages %}
        {% if message['role'] == 'system' %}System: {{ message['content'] }}
        {% elif message['role'] == 'user' %}User: {{ message['content'] }}
        {% elif message['role'] == 'assistant' %}Assistant: {{ message['content'] }}
        {% endif %}
        {% endfor %}
        {% if add_generation_prompt %}Assistant: {% endif %}
        EOF
      '';
    };
  };

  # Performance monitoring service
  systemd.services.vllm-monitor = {
    description = "vLLM Performance Monitor";
    after = ["vllm-server.service"];
    requires = ["vllm-server.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      User = "vllm";
      Group = "vllm";
      ExecStart = "${monitorScript}/bin/vllm-monitor";
      Restart = "always";
      StandardOutput = "journal";
    };
  };

  # NVIDIA persistence daemon for better GPU performance
  systemd.services.nvidia-persistenced = {
    description = "NVIDIA Persistence Daemon";
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${config.hardware.nvidia.package}/bin/nvidia-persistenced --no-persistence-mode --verbose";
      Restart = "always";
    };
  };

  # Firewall configuration
  # networking.firewall = {
  #   allowedTCPPorts = [
  #     8000 # vLLM API
  #     9090 # Prometheus metrics (if needed)
  #   ];
  # };

  # Kernel parameters for maximum performance
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    "transparent_hugepage=always"
    "hugepagesz=1G"
    "hugepages=16"
    "intel_idle.max_cstate=0" # Disable CPU idle states
    "processor.max_cstate=0"
    "idle=poll" # Keep CPU at maximum frequency
    "isolcpus=8-15" # Isolate CPU cores for vLLM (adjust based on your CPU)
  ];

  # Sysctl settings for network and memory optimization
  boot.kernel.sysctl = {
    # Network optimizations for API serving
    "net.core.rmem_default" = 134217728;
    "net.core.rmem_max" = 536870912;
    "net.core.wmem_default" = 134217728;
    "net.core.wmem_max" = 536870912;
    "net.ipv4.tcp_rmem" = "4096 87380 536870912";
    "net.ipv4.tcp_wmem" = "4096 65536 536870912";
    "net.core.netdev_max_backlog" = 30000;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";

    # Memory optimizations
    "vm.swappiness" = 1;
    "vm.dirty_ratio" = 30;
    "vm.dirty_background_ratio" = 5;
    "vm.vfs_cache_pressure" = 50;
    "kernel.shmmax" = 68719476736;
    "kernel.shmall" = 4294967296;
    "vm.max_map_count" = 2147483642;
    "vm.hugetlb_shm_group" = 0;
  };

  # Additional performance tuning
  # managed via configuration of the desktop
  # powerManagement = {
  #   enable = false; # Disable all power management
  #   cpuFreqGovernor = "performance";
  # };

  # Disable CPU frequency scaling
  # services.thermald.enable = false;

  # Environment variables
  environment.variables = {
    CUDA_CACHE_DISABLE = "0";
    CUDA_CACHE_MAXSIZE = "2147483648";
    CUDA_FORCE_PTX_JIT = "0";
    TF_FORCE_GPU_ALLOW_GROWTH = "true";
    TF_GPU_THREAD_MODE = "gpu_private";
  };

  # Convenience aliases for management
  environment.shellAliases = {
    vllm-status = "systemctl status vllm-server";
    vllm-logs = "journalctl -u vllm-server -f";
    vllm-restart = "sudo systemctl restart vllm-server";
    vllm-stop = "sudo systemctl stop vllm-server";
    vllm-start = "sudo systemctl start vllm-server";
    vllm-test = "curl -X POST http://localhost:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\": \"qwen3-coder\", \"messages\": [{\"role\": \"user\", \"content\": \"Write a hello world in Rust\"}]}'";
    gpu-status = "nvidia-smi";
    gpu-monitor = "nvtop";
  };
}
