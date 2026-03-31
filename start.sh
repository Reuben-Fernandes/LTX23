#!/bin/bash
#
# Pod start script — LTX Video 2.3
# Installs custom nodes and downloads models IN PARALLEL, then starts ComfyUI + Jupyter
#
set -e

COMFYUI_DIR=/workspace/ComfyUI
VENV_PIP="$COMFYUI_DIR/.venv/bin/pip"
VENV_PYTHON="$COMFYUI_DIR/.venv/bin/python"
NODES_DIR="$COMFYUI_DIR/custom_nodes"
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

# ══════════════════════════════════════════════════════════════════
#  FUNCTION: Install custom nodes
# ══════════════════════════════════════════════════════════════════
install_nodes() {
    echo ""
    echo "========================================"
    echo "  NODES: Installing custom nodes"
    echo "========================================"

    mkdir -p "$NODES_DIR"

    for repo in \
        "https://github.com/ltdrdata/ComfyUI-Manager" \
        "https://github.com/Lightricks/ComfyUI-LTXVideo" \
        "https://github.com/city96/ComfyUI-GGUF" \
        "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite" \
        "https://github.com/kijai/ComfyUI-KJNodes" \
        "https://github.com/rgthree/rgthree-comfy" \
        "https://github.com/yolain/ComfyUI-Easy-Use" \
        "https://github.com/olduvai-jp/ComfyUI-S3-IO"
    do
        dir="${repo##*/}"
        path="$NODES_DIR/$dir"
        echo "  → $dir"
        if [[ -d "$path" ]]; then
            (cd "$path" && git pull --quiet --recurse-submodules) || true
        else
            git clone "$repo" "$path" --quiet --recursive
        fi
        if [[ -f "$path/requirements.txt" ]]; then
            $VENV_PIP install -r "$path/requirements.txt" --quiet 2>/dev/null || true
        fi
    done

    echo "  ✓ Nodes ready"
}

# ══════════════════════════════════════════════════════════════════
#  FUNCTION: Download models
# ══════════════════════════════════════════════════════════════════
download_models() {
    echo ""
    echo "========================================"
    echo "  MODELS: Downloading from mirror"
    echo "========================================"

    $VENV_PYTHON << PYEOF
import os, shutil
from huggingface_hub import hf_hub_download

token = os.environ["HF_TOKEN"]
mirror = "$MIRROR"
base = "$COMFYUI_DIR/models"

models = [
    # ── Diffusion model (GGUF distilled for 24GB VRAM) ───────────
    ("diffusion_models/LTX-2.3-distilled-Q4_K_S.gguf",                       "diffusion_models"),

    # ── Text encoder (Gemma 3 GGUF + text projection) ────────────
    ("text_encoders/gemma-3-12b-it-Q2_K.gguf",                               "text_encoders"),
    ("text_encoders/ltx-2.3_text_projection_bf16.safetensors",                "text_encoders"),

    # ── VAE (split: video + audio + tiny preview) ────────────────
    ("vae/LTX23_video_vae_bf16.safetensors",                                  "vae"),
    ("vae/LTX23_audio_vae_bf16.safetensors",                                  "vae"),
    ("vae/taeltx2_3.safetensors",                                             "vae"),

    # ── Latent upscalers ─────────────────────────────────────────
    ("latent_upscale_models/ltx-2.3-spatial-upscaler-x2-1.0.safetensors",    "latent_upscale_models"),
    ("latent_upscale_models/ltx-2.3-temporal-upscaler-x2-1.0.safetensors",   "latent_upscale_models"),

    # ── Distilled LoRA (needed for two-stage upscale pipeline) ───
    ("loras/ltx-2.3-22b-distilled-lora-384.safetensors",                     "loras"),
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
print("  ✓ Models ready")
PYEOF
}

# ══════════════════════════════════════════════════════════════════
#  RUN BOTH IN PARALLEL
# ══════════════════════════════════════════════════════════════════
echo "  → Starting parallel setup (nodes + models)..."

download_models &
MODEL_PID=$!

install_nodes &
NODES_PID=$!

# Wait for both — capture exit codes
MODEL_OK=0; NODES_OK=0
wait $MODEL_PID || MODEL_OK=1
wait $NODES_PID || NODES_OK=1

echo ""
if [[ $MODEL_OK -eq 0 && $NODES_OK -eq 0 ]]; then
    echo "✓ All setup complete"
else
    [[ $MODEL_OK -ne 0 ]] && echo "⚠️  Some model downloads failed"
    [[ $NODES_OK -ne 0 ]] && echo "⚠️  Some node installs failed"
fi

# ── Download Workflows ───────────────────────────────────────────
echo "  → Downloading workflows..."
mkdir -p "$COMFYUI_DIR/user/default/workflows"
curl -fsSL https://raw.githubusercontent.com/Reuben-Fernandes/ComfyUI-Workflows/main/LTX_2_3.json \
    -o "$COMFYUI_DIR/user/default/workflows/LTX_2_3.json" && echo "  ✓ LTX_2_3.json" || true

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
