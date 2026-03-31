# LTX Video 2.3 – RunPod Template

Docker template for running **LTX-2.3** (22B) video generation via ComfyUI on RunPod.

Built for **RTX 4090 (24GB VRAM)** using GGUF quantised models.

## Architecture

The image is kept lean — only ComfyUI core + SageAttention are baked in. Custom nodes and models install **in parallel** at first boot, so node changes never require a Docker rebuild.

```
Docker image (baked)          start.sh (at boot, parallel)
├── ComfyUI + venv            ├── Custom nodes (git clone + pip)
├── SageAttention wheel       └── Models (HF mirror download)
├── huggingface_hub           
└── system deps (ffmpeg etc)  → Both finish before ComfyUI launches
```

### Boot timeline (first run)
```
0s ──┬── Model downloads start ─────────────────────── ~5-10 min ──┐
     └── Node installs start ── ~1-2 min ──┐                      │
                                           ✓ nodes done           │
                                                    ✓ models done ─┤
                                                                   ├── ComfyUI launches
                                                                   └── Jupyter launches
```

Subsequent boots skip existing models — nodes get a `git pull` to stay current.

## What's included

### Baked into Docker image
- ComfyUI (latest at build time)
- SageAttention 2.2.0 (pre-compiled SM89/Ada wheel)
- huggingface_hub + hf_transfer

### Installed at boot (custom nodes)
- ComfyUI-Manager
- ComfyUI-LTXVideo (Lightricks)
- ComfyUI-GGUF
- ComfyUI-VideoHelperSuite
- ComfyUI-KJNodes
- rgthree-comfy
- ComfyUI-Easy-Use
- ComfyUI-S3-IO

### Downloaded at boot (from `ReubenF10/ComfyUI-Models`)

| File | Folder | Size | Purpose |
|------|--------|------|---------|
| `LTX-2.3-distilled-Q4_K_S.gguf` | `diffusion_models/` | ~12 GB | Main I2V/T2V model (GGUF) |
| `gemma-3-12b-it-Q2_K.gguf` | `text_encoders/` | ~5 GB | Gemma 3 text encoder (GGUF) |
| `ltx-2.3_text_projection_bf16.safetensors` | `text_encoders/` | ~0.5 GB | Text projection connector |
| `LTX23_video_vae_bf16.safetensors` | `vae/` | ~1.5 GB | Video VAE |
| `LTX23_audio_vae_bf16.safetensors` | `vae/` | ~365 MB | Audio VAE |
| `taeltx2_3.safetensors` | `vae/` | small | Tiny VAE for sampler previews |
| `ltx-2.3-spatial-upscaler-x2-1.0.safetensors` | `latent_upscale_models/` | ~996 MB | 2× spatial latent upscaler |
| `ltx-2.3-temporal-upscaler-x2-1.0.safetensors` | `latent_upscale_models/` | ~262 MB | 2× temporal upscaler |
| `ltx-2.3-22b-distilled-lora-384.safetensors` | `loras/` | ~7.6 GB | Distilled LoRA for two-stage pipeline |

## RunPod setup

1. **Create template** using the Docker image from this repo
2. **Set environment variable**: `HF_TOKEN` = your HuggingFace token
3. **Expose ports**: `8188` (ComfyUI), `8888` (Jupyter Lab)
4. **GPU**: RTX 4090 or equivalent 24GB+ card
5. **Volume**: attach network volume to `/workspace` for persistence

## Changing nodes

Edit the `install_nodes()` function in `start.sh` — add or remove repos from the list. No Docker rebuild needed. Changes take effect on next pod start.

## Ports

| Port | Service |
|------|---------|
| 8188 | ComfyUI |
| 8888 | Jupyter Lab |
