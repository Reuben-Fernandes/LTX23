#!/bin/bash
#
# Pod start script — LTX Video 2.3
# Downloads models on first run, then starts ComfyUI + Jupyter
#
set -e
COMFYUI_DIR=/workspace/ComfyUI
VENV_PYTHON="$COMFYUI_DIR/.venv/bin/python"
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
base = "$COMFYUI_DIR/models"
# (repo_id, filename, destination_folder)
models = [
    # ── Checkpoint (fp8 dev + distilled LoRA for two-stage) ──────
    ("Lightricks/LTX-2.3-fp8",  "ltx-2.3-22b-dev-fp8.safetensors",            "checkpoints"),
    ("Lightricks/LTX-2.3",      "ltx-2.3-22b-distilled-lora-384.safetensors",  "loras"),
    # ── Spatial upscaler (v1.1 hotfix) ───────────────────────────
    ("Lightricks/LTX-2.3",      "ltx-2.3-spatial-upscaler-x2-1.1.safetensors", "latent_upscale_models"),
]
# No Gemma download — using Gemma API for text encoding
for repo_id, filename, dest_folder in models:
    save_name = filename.split("/")[-1]
    dest = os.path.join(base, dest_folder, save_name)
    if os.path.exists(dest):
        print(f"  ⏭  Already exists: {save_name}")
        continue
    os.makedirs(os.path.join(base, dest_folder), exist_ok=True)
    print(f"  → Downloading: {save_name}")
    path = hf_hub_download(
        repo_id=repo_id,
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
