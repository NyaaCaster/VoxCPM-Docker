#!/usr/bin/env bash
# Container entrypoint for VoxCPM.
#
# Ensures the model is available before launching the Gradio app:
#   - If VOXCPM_MODEL_ID points at a local directory (the default,
#     /models/VoxCPM2, bind-mounted from the host), download the weights into it
#     when missing. Subsequent starts are a fast no-op.
#   - If VOXCPM_MODEL_ID is a Hugging Face repo id, skip the pre-download and let
#     the application resolve/download it at load time.
#
# exec replaces this shell with python so the app becomes PID 1 and receives
# signals (graceful shutdown) directly.
set -euo pipefail

MODEL_ID="${VOXCPM_MODEL_ID:-/models/VoxCPM2}"

if [[ "${MODEL_ID}" == /* ]]; then
    echo "[entrypoint] local model dir: ${MODEL_ID} — ensuring weights are present"
    VOXCPM_LOCAL_MODEL_DIR="${MODEL_ID}" python3 /app/scripts/fetch_model.py
else
    echo "[entrypoint] VOXCPM_MODEL_ID='${MODEL_ID}' is a repo id — app will resolve it at load time"
fi

echo "[entrypoint] starting VoxCPM on port ${VOXCPM_PORT:-8808} (device: ${VOXCPM_DEVICE:-auto})"
exec python3 app.py \
    --model-id "${MODEL_ID}" \
    --device "${VOXCPM_DEVICE:-auto}" \
    --port "${VOXCPM_PORT:-8808}"
