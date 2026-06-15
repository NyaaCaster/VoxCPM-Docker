FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HF_HOME=/cache/huggingface \
    HUGGINGFACE_HUB_CACHE=/cache/huggingface/hub \
    TRANSFORMERS_CACHE=/cache/huggingface/transformers \
    TORCH_HOME=/cache/torch \
    GRADIO_TEMP_DIR=/tmp/gradio \
    TOKENIZERS_PARALLELISM=false \
    SETUPTOOLS_SCM_PRETEND_VERSION_FOR_VOXCPM=0.0.0+docker \
    CC=gcc \
    CXX=g++ \
    VOXCPM_MODEL_ID=/models/VoxCPM2 \
    VOXCPM_DEVICE=auto \
    VOXCPM_PORT=8808

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        ffmpeg \
        g++ \
        gcc \
        git \
        libsndfile1 \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m pip install --upgrade pip setuptools wheel

COPY pyproject.toml README.md README_zh.md LICENSE ./
COPY src ./src
COPY app.py ./app.py
COPY assets ./assets

RUN python3 -m pip install --index-url https://download.pytorch.org/whl/cu124 \
        "torch>=2.5.0" "torchaudio>=2.5.0" \
    && python3 -m pip install -e .

RUN mkdir -p \
        /models \
        /cache/huggingface \
        /cache/torch \
        /data \
        /outputs \
        /tmp/gradio

EXPOSE 8808

CMD ["bash", "-lc", "python3 app.py --model-id \"${VOXCPM_MODEL_ID}\" --device \"${VOXCPM_DEVICE}\" --port \"${VOXCPM_PORT}\""]
