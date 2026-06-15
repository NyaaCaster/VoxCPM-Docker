# Docker deployment

This project is deployed as a single Gradio service. Large, persistent, low-frequency assets are bind-mounted under the directory set by `VOXCPM_ASSET_ROOT` so model weights and caches do not grow the Docker image, Docker volumes, WSL virtual disk, or the system drive.

## Quick start (one-click)

For a guided first-time setup, run the interactive `FirstBuild.ps1`. It generates `.env` (port, asset path, Hugging Face token), pre-downloads the model, builds and starts the container, and prints the URL to open. It supports English and Chinese prompts.

```powershell
pwsh -NoProfile -File FirstBuild.ps1
```

The rest of this document describes the manual steps that `FirstBuild.ps1` automates.

`VOXCPM_ASSET_ROOT` is the single source of truth for the host asset location. It is defined once in `.env` and consumed by `docker-compose.yml` and `scripts/download_models.py`. The `.env.example` default is `.` (the project root) for portability; for production set it to a storage drive with enough free space, for example `E:/DockerRes/VoxCPM`. The examples below use `$ASSET_ROOT` as a placeholder for that value.

## Host directory layout

Create the large-asset directories before downloading models or starting Docker. Substitute your `VOXCPM_ASSET_ROOT` value for `$ASSET_ROOT`:

```powershell
$ASSET_ROOT = "E:\DockerRes\VoxCPM"   # match VOXCPM_ASSET_ROOT in .env
New-Item -ItemType Directory -Force `
  "$ASSET_ROOT\models", `
  "$ASSET_ROOT\cache\huggingface", `
  "$ASSET_ROOT\cache\torch", `
  "$ASSET_ROOT\data", `
  "$ASSET_ROOT\outputs", `
  "$ASSET_ROOT\tmp\gradio"
```

The default container mapping is (host paths relative to `VOXCPM_ASSET_ROOT`):

| Host path | Container path | Purpose |
| --- | --- | --- |
| `$ASSET_ROOT/models` | `/models` | Pre-downloaded VoxCPM model directories |
| `$ASSET_ROOT/cache/huggingface` | `/cache/huggingface` | Hugging Face / Transformers cache |
| `$ASSET_ROOT/cache/torch` | `/cache/torch` | PyTorch cache |
| `$ASSET_ROOT/data` | `/data` | Input data and reference audio |
| `$ASSET_ROOT/outputs` | `/outputs` | Generated outputs |
| `$ASSET_ROOT/tmp/gradio` | `/tmp/gradio` | Gradio upload/temp files |

## Pre-download large model files

Run the pre-download script before `docker compose build` / `docker compose up`. This keeps large model files under `VOXCPM_ASSET_ROOT` and out of image layers. With no `--root`, the script reads `VOXCPM_ASSET_ROOT` from `.env` (falling back to the project root):

```powershell
python scripts/download_models.py
```

To override the location explicitly, pass `--root`:

```powershell
python scripts/download_models.py --root "E:\DockerRes\VoxCPM"
```

The script downloads the main Hugging Face model `openbmb/VoxCPM2` to:

```text
$ASSET_ROOT\models\VoxCPM2
```

Hugging Face downloads use the bundled `hf-xet\scripts\hf-download.ps1` helper only. The helper reads `HF_Token` from this project's real `.env`, enables `HF_XET_HIGH_PERFORMANCE=1`, uses the official `hf download` / hf-xet path, and writes the model to the target directory.

This project intentionally does not use aria2 for Hugging Face files. HF Xet-backed model files are not plain static direct downloads; direct multi-connection downloads can produce incomplete or corrupted files.

Useful options:

```powershell
python scripts/download_models.py --max-workers 8
python scripts/download_models.py --force-download
```

## Configure environment

Copy the example file if you want to customize defaults:

```powershell
Copy-Item .env.example .env
```

Default values:

```dotenv
VOXCPM_HOST_PORT=5106
VOXCPM_DEVICE=auto
VOXCPM_MODEL_ID=/models/VoxCPM2
HF_Token=
```

Use `VOXCPM_MODEL_ID=/models/VoxCPM2` for the pre-downloaded host model. `HF_Token` is consumed only by the bundled `hf-xet` download scripts and should stay in the untracked `.env` file. To let the container download from Hugging Face at runtime instead, set:

```dotenv
VOXCPM_MODEL_ID=openbmb/VoxCPM2
```

## Build and start

```powershell
docker compose up --build
```

Open the Web UI at:

```text
http://localhost:5106
```

The container listens on port `8808`; Docker exposes it on host port `5106` by default.

## GPU and CPU modes

The compose file requests all NVIDIA GPUs with Docker Compose device reservations. On Windows, GPU mode requires Docker Desktop with WSL2 and working NVIDIA container support.

Check GPU visibility after the service starts:

```powershell
docker compose exec voxcpm nvidia-smi
```

For CPU fallback, set this in `.env`:

```dotenv
VOXCPM_DEVICE=cpu
```

CPU inference for the VoxCPM2 2B model is expected to be slow.

## Verification

Run these checks after creating the files:

```powershell
docker compose config
python scripts/download_models.py --help
```

After pre-downloading, confirm the main model exists (substitute your `VOXCPM_ASSET_ROOT` value):

```powershell
$ASSET_ROOT = "E:\DockerRes\VoxCPM"   # match VOXCPM_ASSET_ROOT in .env
Test-Path "$ASSET_ROOT\models\VoxCPM2\config.json"
Test-Path "$ASSET_ROOT\models\VoxCPM2\model.safetensors"
Test-Path "$ASSET_ROOT\models\VoxCPM2\audiovae.pth"
```

After startup:

- Check logs show Gradio listening on `0.0.0.0:8808`.
- Visit `http://localhost:5106`.
- Generate a short test sentence in the UI.
- Confirm new cache/temp files are under `$ASSET_ROOT\cache` or `$ASSET_ROOT\tmp\gradio`.

## Notes

- The first pre-download can take a long time and requires enough free space under `VOXCPM_ASSET_ROOT`.
- If you need fully offline runtime, pre-download the main model and keep `VOXCPM_MODEL_ID=/models/VoxCPM2`.
- The Docker image does not include model weights. Rebuilding the image should not duplicate the large assets.
