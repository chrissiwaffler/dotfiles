#!/bin/bash
# Qwen3-Coder-30B vLLM server for RTX 5090

# Force NVIDIA GPU usage
export CUDA_VISIBLE_DEVICES=0
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
export HIP_VISIBLE_DEVICES=""  # Disable AMD ROCm
export ROCR_VISIBLE_DEVICES=""  # Disable AMD ROCm

# Check GPU availability
echo "=== GPU Check ==="
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
echo "CUDA devices: $(python -c 'import torch; print(torch.cuda.device_count())')"
echo "Current device: $(python -c 'import torch; print(torch.cuda.get_device_name())' 2>/dev/null || echo 'CUDA not available')"
echo "================="

python -m vllm.entrypoints.openai.api_server \
  --model "Qwen/Qwen2.5-Coder-32B-Instruct" \
  --host 0.0.0.0 \
  --port 8000 \
  --dtype bfloat16 \
  --gpu-memory-utilization 0.90 \
  --max-model-len 32768 \
  --max-num-seqs 32 \
  --tensor-parallel-size 1 \
  --enable-prefix-caching \
  --disable-log-requests \
  --served-model-name "qwen-coder"