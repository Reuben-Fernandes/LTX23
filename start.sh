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
$VENV_PYTHON << 'PYEOF'
import os, shutil, sys, threading, time
from huggingface_hub import hf_hub_download, HfApi

token = os.environ["HF_TOKEN"]
base = "/workspace/ComfyUI/models"

models = [
    ("Lightricks/LTX-2.3-fp8",  "ltx-2.3-22b-dev-fp8.safetensors",            "checkpoints"),
    ("Lightricks/LTX-2.3",      "ltx-2.3-22b-distilled-lora-384.safetensors",  "loras"),
    ("Lightricks/LTX-2.3",      "ltx-2.3-spatial-upscaler-x2-1.1.safetensors", "latent_upscale_models"),
]

def get_remote_size(repo_id, filename):
    try:
        api = HfApi()
        info = api.model_info(repo_id, token=token, files_metadata=True)
        for f in info.siblings:
            if f.rfilename == filename:
                return f.size
    except:
        pass
    return None

def poll_progress(tmp_path, total_bytes, stop_event, label):
    bar_width = 30
    while not stop_event.is_set():
        try:
            current = os.path.getsize(tmp_path) if os.path.exists(tmp_path) else 0
        except:
            current = 0
        if total_bytes:
            pct = min(int((current / total_bytes) * 100), 100)
            filled = int(bar_width * current / total_bytes)
            bar = '█' * filled + '░' * (bar_width - filled)
            curr_mb = current / 1024 / 1024
            total_mb = total_bytes / 1024 / 1024
            sys.stdout.write(f"\r    [{bar}] {pct:3d}%  {curr_mb:.0f} / {total_mb:.0f} MB")
        else:
            curr_mb = current / 1024 / 1024
            sys.stdout.write(f"\r    Downloading... {curr_mb:.0f} MB received")
        sys.stdout.flush()
        time.sleep(0.5)
    sys.stdout.write("\n")
    sys.stdout.flush()

for repo_id, filename, dest_folder in models:
    save_name = filename.split("/")[-1]
    dest = os.path.join(base, dest_folder, save_name)
    if os.path.exists(dest):
        print(f"  ⏭  Already exists: {save_name}")
        continue
    os.makedirs(os.path.join(base, dest_folder), exist_ok=True)
    print(f"  → Downloading: {save_name}")

    # Get remote file size for progress bar
    total_bytes = get_remote_size(repo_id, filename)

    # hf_transfer downloads to a temp file inside local_dir
    tmp_dir = f"/tmp/hf_dl/{repo_id.replace('/', '_')}"
    tmp_path = os.path.join(tmp_dir, filename)

    # Start progress polling in background
    stop_event = threading.Event()
    t = threading.Thread(
        target=poll_progress,
        args=(tmp_path, total_bytes, stop_event, save_name),
        daemon=True
    )
    t.start()

    # Run the actual download
    path = hf_hub_download(
        repo_id=repo_id,
        filename=filename,
        token=token,
        local_dir=tmp_dir,
        local_dir_use_symlinks=False,
    )

    # Stop progress bar
    stop_event.set()
    t.join()

    size_mb = os.path.getsize(path) / 1024 / 1024
    shutil.move(path, dest)
    print(f"  ✓ Saved: {save_name} ({size_mb:.0f} MB)")

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
