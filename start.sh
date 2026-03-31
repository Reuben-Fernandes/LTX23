#!/bin/bash
#
# Pod start script — LTX Video 2.3
# Downloads models on first run, then starts ComfyUI + Jupyter
#
set -e

COMFYUI_DIR=/workspace/ComfyUI
VENV_PYTHON="$COMFYUI_DIR/.venv/bin/python"
MIRROR="ReubenF10/ComfyUI-Models"

echo ""
echo "########################################"
echo "#       LTX Video 2.3 - Starting      #"
echo "########################################"
echo ""

if [[ -z "$HF_TOKEN" ]]; then
    echo "ERROR: HF_TOKEN not set. Add it as a RunPod environment variable."
    exit 1
fi
export HF_TOKEN
export HF_HUB_ENABLE_HF_TRANSFER=1

# ── Download Models ──────────────────────────────────────────────
echo "  → Checking models..."

$VENV_PYTHON << PYEOF
import os, shutil
from huggingface_hub import hf_hub_download

token = os.environ["HF_TOKEN"]
mirror = "$MIRROR"
base = "$COMFYUI_DIR/models"

models = [
    # ── Diffusion model (GGUF distilled for 24GB VRAM) ───────────
    ("diffusion_models/LTX-2.3-distilled-Q4_K_S.gguf",                       "unet"),

    # ── Text encoder (Gemma 3 GGUF + text projection) ────────────
    ("text_encoders/gemma-3-12b-it-Q2_K.gguf",                               "text_encoders"),
    ("text_encoders/ltx-2.3_text_projection_bf16.safetensors",                "text_encoders"),

    # ── VAE (split: video + audio + tiny preview) ────────────────
    ("vae/LTX23_video_vae_bf16.safetensors",                                  "vae"),
    ("vae/LTX23_audio_vae_bf16.safetensors",                                  "vae"),
    ("vae/taeltx2_3.safetensors",                                             "vae"),

    # ── Latent upscaler ──────────────────────────────────────────
    ("latent_upscale_models/ltx-2.3-spatial-upscaler-x2-1.0.safetensors",    "latent_upscale_models"),
]

for filename, dest_folder in models:
    save_name = filename.split("/")[-1]
    dest = os.path.join(base, dest_folder, save_name)
    if os.path.exists(dest):
        print(f"  ⏭  Already exists: {save_name}")
        continue
    os.makedirs(os.path.join(base, dest_folder), exist_ok=True)
    print(f"  → Downloading: {save_name}")
    path = hf_hub_download(
        repo_id=mirror,
        filename=filename,
        token=token,
        local_dir="/tmp/hf_dl",
        local_dir_use_symlinks=False
    )
    shutil.move(path, dest)
    print(f"  ✓ Saved: {save_name}")

print("")
print("✓ All models ready")
PYEOF

# ── Launch Jupyter Lab ───────────────────────────────────────────
echo "  → Starting Jupyter Lab on port 8888..."
jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --NotebookApp.token='' \
    --NotebookApp.password='' \
    > /workspace/jupyter.log 2>&1 &

# ── Launch ComfyUI ───────────────────────────────────────────────
echo "  → Launching ComfyUI on port 8188..."
echo ""
exec $VENV_PYTHON "$COMFYUI_DIR/main.py" \
    --listen 0.0.0.0 \
    --port 8188 \
    --use-sage-attention
