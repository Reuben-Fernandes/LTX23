# ── Base ─────────────────────────────────────────────────────────
FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404
ENV HF_HUB_ENABLE_HF_TRANSFER=1
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace
# ── System Dependencies ──────────────────────────────────────────
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        git \
        git-lfs \
        ffmpeg \
        libgl1 \
        libglib2.0-0 \
        build-essential \
        ninja-build \
    && rm -rf /var/lib/apt/lists/*
# ── ComfyUI ──────────────────────────────────────────────────────
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
WORKDIR /workspace/ComfyUI
RUN python3 -m venv .venv && \
    .venv/bin/pip install --upgrade pip --quiet && \
    .venv/bin/pip install -r requirements.txt --quiet
# ── Python Dependencies ──────────────────────────────────────────
RUN .venv/bin/pip install \
    "huggingface_hub[cli]" \
    hf_transfer \
    packaging \
    ninja \
    --quiet
# ── Custom Nodes ─────────────────────────────────────────────────
RUN cd /workspace/ComfyUI/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager && \
    git clone https://github.com/Lightricks/ComfyUI-LTXVideo && \
    git clone https://github.com/evanspearman/ComfyMath
RUN for dir in /workspace/ComfyUI/custom_nodes/*/; do \
        if [ -f "$dir/requirements.txt" ]; then \
            /workspace/ComfyUI/.venv/bin/pip install -r "$dir/requirements.txt" --quiet || true; \
        fi \
    done
# ── Fix torch (node deps may have overwritten it) ────────────────
RUN .venv/bin/pip install \
    torch==2.8.0+cu128 torchvision==0.23.0+cu128 torchaudio==2.8.0+cu128 \
    --index-url https://download.pytorch.org/whl/cu128 \
    --quiet
# ── SageAttention (built on torch 2.8.0+cu128, SM89/RTX 4090) ───
RUN .venv/bin/pip install \
    https://huggingface.co/ReubenF10/ComfyUI-Models/resolve/main/wheels/ltx/sageattention-2.2.0-cp312-cp312-linux_x86_64.whl \
    --quiet
# ── Ports ────────────────────────────────────────────────────────
EXPOSE 8188
EXPOSE 8888
# ── Start Script ─────────────────────────────────────────────────
COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/start.sh"]
