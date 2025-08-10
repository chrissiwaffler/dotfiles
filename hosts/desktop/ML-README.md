# Machine Learning Setup on NixOS with NVIDIA RTX 5090

This configuration provides a complete machine learning development environment with NVIDIA GPU support.

## Features

### NVIDIA GPU Support (`nvidia.nix`)

- Full RTX 5090 support with latest stable/beta drivers
- CUDA and cuDNN integration
- Wayland and X11 compatibility
- GPU monitoring tools (nvidia-smi, nvtop)

### Machine Learning Environment (`machine-learning.nix`)

- **Frameworks**: PyTorch, TensorFlow with CUDA support
- **Scientific Stack**: NumPy, SciPy, Pandas, scikit-learn
- **Deep Learning**: Transformers, Accelerate, Datasets
- **Visualization**: Matplotlib, Seaborn, Plotly
- **Development**: Jupyter Lab, IPython
- **Docker**: NVIDIA Docker support for containerized ML workflows

### Performance Optimizations (`performance.nix`)

- CPU governor management with auto-cpufreq
- Memory optimizations for ML workloads
- ZRAM swap compression
- Early OOM killer to prevent freezes
- Nix build optimizations
- Storage optimizations (TRIM, NVMe)

## Usage

### Quick Start

1. **Check GPU Status**:

   ```bash
   nvidia-smi
   gpu-status  # Alias for nvidia-smi
   gpu-watch   # Watch GPU usage in real-time
   ```

2. **Start ML Development Shell**:

   ```bash
   ml-shell  # Enters a shell with all ML tools configured
   ```

3. **Launch Jupyter Lab**:

   ```bash
   jupyter-lab  # Starts Jupyter Lab server
   ```

4. **Monitor System Performance**:
   ```bash
   nvtop   # GPU monitoring
   btop    # System monitoring
   ```

### Python ML Environment

The system includes a comprehensive Python environment with:

- PyTorch with CUDA support
- TensorFlow with GPU acceleration
- All major data science libraries

Test GPU availability:

```python
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU count: {torch.cuda.device_count()}")
if torch.cuda.is_available():
    print(f"GPU name: {torch.cuda.get_device_name(0)}")
```

### Docker with GPU Support

Run ML containers with GPU access:

```bash
docker run --gpus all nvidia/cuda:12.0-base nvidia-smi
```

### Development Shell

For isolated ML development, use the included shell:

```bash
nix-shell /etc/ml-shell.nix
```

This provides a clean environment with all CUDA paths configured.

## Troubleshooting

### NVIDIA Driver Issues

If the RTX 5090 isn't recognized, you may need to switch to beta drivers:

Edit `/modules/desktop/nvidia.nix`:

```nix
package = config.boot.kernelPackages.nvidiaPackages.beta;
# or
package = config.boot.kernelPackages.nvidiaPackages.production;
```

### CUDA Version Mismatch

Check CUDA version compatibility:

```bash
nvcc --version  # CUDA compiler version
nvidia-smi      # Driver CUDA version
```

### Memory Issues

If running out of memory during training:

1. Check ZRAM status: `zramctl`
2. Adjust swappiness: Already optimized to 10
3. Monitor with: `watch -n 1 free -h`

### Performance Monitoring

Use these tools to identify bottlenecks:

- `nvtop` - GPU utilization
- `btop` - CPU and memory
- `iotop` - Disk I/O
- `turbostat` - CPU frequency and power

## Environment Variables

Key environment variables set by the configuration:

- `CUDA_PATH` - CUDA toolkit location
- `CUDA_VISIBLE_DEVICES` - GPU selection (default: 0)
- `TF_FORCE_GPU_ALLOW_GROWTH` - TensorFlow memory growth
- `TORCH_CUDA_ARCH_LIST` - Supported GPU architectures

## Notes

- The configuration disables some CPU mitigations for maximum performance. Re-enable them for production systems by removing `mitigations=off` from kernel parameters.
- Docker with NVIDIA support is enabled by default. Ensure your user is in the `docker` group.
- The system is optimized for AC power. Battery performance may be reduced.
- Compiler optimizations use native CPU architecture for best performance.

