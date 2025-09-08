{
  config,
  pkgs,
  ...
}: {
  systemd.services.qwen3-coder = {
    description = "vLLM Qwen3-Coder-30B Server";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      Environment = [
        "CUDA_VISIBLE_DEVICES=0"
        "HF_HOME=/var/lib/llm-models"
        "VLLM_ATTENTION_BACKEND=FLASH_ATTN"
      ];
      # Use a shell hook to set up the environment and install vLLM
      ExecStartPre = ''
        ${pkgs.bash}/bin/bash -c "
          source ${pkgs.uv}/bin/uv-activate
          ${pkgs.uv}/bin/uv venv --python ${pkgs.python311}/bin/python3.11 --seed
          source .venv/bin/activate
          ${pkgs.uv}/bin/uv pip install vllm --torch-backend=auto
        "
      '';
      ExecStart = ''
        ${pkgs.bash}/bin/bash -c "
          source .venv/bin/activate
          ${pkgs.python311}/bin/vllm serve \
            Qwen/Qwen3-Coder-30B-A3B-Instruct \
            --host 0.0.0.0 \
            --port 8000 \
            --gpu-memory-utilization 0.90 \
            --max-model-len 65536 \
            --dtype auto
        "
      '';
      Restart = "always";
    };
  };
}
