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

model
