#!/usr/bin/env python3
"""Download VoxCPM model weights inside the container, into the bind-mounted /models.

This runs at container startup (see docker/entrypoint.sh). It downloads only when
the target model directory is missing required files, so it is a fast no-op on
restarts and after rebuilds — the weights live on the host bind mount, not in the
image. Downloads go through huggingface_hub with hf-xet acceleration enabled in
the image; an HF token, if provided via the HF_TOKEN env var, is used for
authenticated access.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

VOXCPM_HF_ID = "openbmb/VoxCPM2"
DEFAULT_TARGET = Path("/models/VoxCPM2")
REQUIRED_VOXCPM_FILES = (
    "config.json",
    "tokenizer.json",
    "tokenizer_config.json",
    "model.safetensors",
    "audiovae.pth",
)


def log(message: str) -> None:
    print(f"[fetch_model] {message}", flush=True)


def looks_complete(model_dir: Path) -> bool:
    return all((model_dir / name).is_file() for name in REQUIRED_VOXCPM_FILES)


def missing_files(model_dir: Path) -> list[str]:
    return [name for name in REQUIRED_VOXCPM_FILES if not (model_dir / name).is_file()]


def resolve_token() -> str | None:
    # huggingface_hub reads HF_TOKEN natively; accept a few common aliases too.
    for name in ("HF_TOKEN", "HF_Token", "HUGGING_FACE_HUB_TOKEN", "HUGGINGFACE_TOKEN"):
        value = os.environ.get(name)
        if value and value.strip():
            return value.strip()
    return None


def main() -> int:
    target = Path(os.environ.get("VOXCPM_LOCAL_MODEL_DIR", str(DEFAULT_TARGET)))
    target.mkdir(parents=True, exist_ok=True)

    if looks_complete(target):
        log(f"model already present, skipping download: {target}")
        return 0

    log(f"model incomplete at {target} (missing: {', '.join(missing_files(target))})")
    log(f"downloading {VOXCPM_HF_ID} via huggingface_hub (hf-xet enabled)...")

    try:
        from huggingface_hub import snapshot_download
    except ImportError as exc:  # pragma: no cover - image always provides it
        log(f"error: huggingface_hub is not installed: {exc}")
        return 1

    token = resolve_token()
    if token:
        log("using HF token from environment for authenticated download.")
    else:
        log("no HF token found; downloading anonymously.")

    try:
        snapshot_download(
            repo_id=VOXCPM_HF_ID,
            repo_type="model",
            local_dir=str(target),
            token=token,
            max_workers=int(os.environ.get("VOXCPM_DOWNLOAD_WORKERS", "8")),
        )
    except Exception as exc:  # noqa: BLE001 - surface any download failure clearly
        log(f"error: download failed: {exc}")
        return 1

    if not looks_complete(target):
        log(f"error: download finished but files still missing: {', '.join(missing_files(target))}")
        return 2

    log(f"done: model ready at {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
