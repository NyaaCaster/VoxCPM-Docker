#!/usr/bin/env python3
"""Pre-download VoxCPM Docker assets with the bundled hf-xet helper.

The script keeps large model files out of Docker image layers by downloading them
under VOXCPM_ASSET_ROOT (read from .env, defaulting to the project root) or a
caller-provided --root, before docker compose build/up runs. Hugging Face assets
are downloaded only through hf-xet; aria2 is intentionally not used for HF/Xet-backed
files.
"""

from __future__ import annotations

import argparse
import os
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = PROJECT_ROOT
VOXCPM_HF_ID = "openbmb/VoxCPM2"
HF_XET_DOWNLOAD_SCRIPT = PROJECT_ROOT / "hf-xet" / "scripts" / "hf-download.ps1"
PROJECT_ENV = PROJECT_ROOT / ".env"
REQUIRED_VOXCPM_FILES = (
    "config.json",
    "tokenizer.json",
    "tokenizer_config.json",
    "model.safetensors",
    "audiovae.pth",
)


def log(message: str) -> None:
    print(f"[download_models] {message}", flush=True)


def load_dotenv(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip().strip('"').strip("'")
        values[key.strip()] = value
    return values


def resolve_asset_root(cli_root: Path | None) -> Path:
    if cli_root is not None:
        return cli_root.expanduser().resolve()
    env_value = load_dotenv(PROJECT_ENV).get("VOXCPM_ASSET_ROOT") or os.environ.get("VOXCPM_ASSET_ROOT")
    if env_value:
        return Path(env_value).expanduser().resolve()
    return DEFAULT_ROOT


def ensure_layout(root: Path) -> dict[str, Path]:
    paths = {
        "models": root / "models",
        "voxcpm2": root / "models" / "VoxCPM2",
        "hf_cache": root / "cache" / "huggingface",
        "torch_cache": root / "cache" / "torch",
        "data": root / "data",
        "outputs": root / "outputs",
        "gradio_tmp": root / "tmp" / "gradio",
    }
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)
    return paths


def configure_cache_env(paths: dict[str, Path]) -> None:
    os.environ.setdefault("HF_HOME", str(paths["hf_cache"]))
    os.environ.setdefault("HUGGINGFACE_HUB_CACHE", str(paths["hf_cache"] / "hub"))
    os.environ.setdefault("TRANSFORMERS_CACHE", str(paths["hf_cache"] / "transformers"))
    os.environ.setdefault("TORCH_HOME", str(paths["torch_cache"]))


def looks_like_voxcpm_model(model_dir: Path) -> bool:
    return all((model_dir / name).is_file() for name in REQUIRED_VOXCPM_FILES)


def cleanup_partial_state(model_dir: Path) -> None:
    # Clean stale state left by previous direct-download attempts.
    for state_file in model_dir.glob("*.aria2"):
        try:
            state_file.unlink()
        except OSError as exc:
            log(f"warning: failed to remove stale partial download state {state_file}: {exc}")


def run(cmd: list[str], *, cwd: Path | None = None) -> None:
    log("running: " + " ".join(cmd))
    subprocess.run(cmd, cwd=str(cwd) if cwd else None, check=True)


def download_voxcpm_hf_xet(output_dir: Path, cache_workdir: Path, *, max_workers: int, force_download: bool) -> None:
    if looks_like_voxcpm_model(output_dir) and not force_download:
        cleanup_partial_state(output_dir)
        log(f"main model already exists: {output_dir}")
        return

    if not HF_XET_DOWNLOAD_SCRIPT.is_file():
        raise RuntimeError(f"hf-xet helper not found: {HF_XET_DOWNLOAD_SCRIPT}")

    cache_workdir.mkdir(parents=True, exist_ok=True)
    cmd = [
        "powershell",
        "-NoProfile",
        "-File",
        str(HF_XET_DOWNLOAD_SCRIPT),
        VOXCPM_HF_ID,
        "-LocalDir",
        str(output_dir),
        "-MaxWorkers",
        str(max_workers),
        "-EnvPath",
        str(PROJECT_ENV),
    ]
    if force_download:
        cmd.append("-ForceDownload")

    run(cmd, cwd=cache_workdir)
    cleanup_partial_state(output_dir)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Pre-download VoxCPM Docker model assets with hf-xet")
    parser.add_argument("--root", type=Path, help="large asset root; defaults to VOXCPM_ASSET_ROOT from .env, then project root")
    parser.add_argument("--max-workers", type=int, default=8, help="hf-xet max worker count (default: 8)")
    parser.add_argument("--force-download", action="store_true", help="force re-download through hf-xet")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    asset_root = resolve_asset_root(args.root)
    paths = ensure_layout(asset_root)
    configure_cache_env(paths)

    log(f"asset root: {asset_root}")
    log(f"hf-xet helper: {HF_XET_DOWNLOAD_SCRIPT if HF_XET_DOWNLOAD_SCRIPT.is_file() else 'not found'}")

    download_voxcpm_hf_xet(
        paths["voxcpm2"],
        paths["hf_cache"],
        max_workers=max(1, args.max_workers),
        force_download=args.force_download,
    )

    if not looks_like_voxcpm_model(paths["voxcpm2"]):
        missing = [name for name in REQUIRED_VOXCPM_FILES if not (paths["voxcpm2"] / name).is_file()]
        log(f"warning: {paths['voxcpm2']} is missing required files: {', '.join(missing)}")
        return 2

    log("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
