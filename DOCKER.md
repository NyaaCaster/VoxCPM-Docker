# Docker deployment

This project is deployed as a single Gradio service. Large, persistent, low-frequency assets are bind-mounted under the directory set by `VOXCPM_ASSET_ROOT` so model weights and caches do not grow the Docker image, Docker volumes, WSL virtual disk, or the system drive.

## Quick start (one-click)

For a guided first-time setup, run the interactive `FirstBuild.ps1`. It generates `.env` (port, asset path, Hugging Face token), builds and starts the container, and prints the URL to open. The model is downloaded inside the container on first start. It supports English and Chinese prompts.

```powershell
pwsh -NoProfile -File FirstBuild.ps1
```

The rest of this document describes the manual steps that `FirstBuild.ps1` automates.

`VOXCPM_ASSET_ROOT` is the single source of truth for the host asset location. It is defined once in `.env` and consumed by `docker-compose.yml`. The `.env.example` default is `.` (the project root) for portability; for production set it to a storage drive with enough free space, for example `E:/DockerRes/VoxCPM`. The examples below use `$ASSET_ROOT` as a placeholder for that value.

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
| `$ASSET_ROOT/models` | `/models` | VoxCPM model directories (downloaded in-container) |
| `$ASSET_ROOT/cache/huggingface` | `/cache/huggingface` | Hugging Face / Transformers cache |
| `$ASSET_ROOT/cache/torch` | `/cache/torch` | PyTorch cache |
| `$ASSET_ROOT/data` | `/data` | Input data and reference audio |
| `$ASSET_ROOT/outputs` | `/outputs` | Generated outputs |
| `$ASSET_ROOT/tmp/gradio` | `/tmp/gradio` | Gradio upload/temp files |

> The host directories are created automatically by Docker when the bind mounts are first used, so you do not have to pre-create them.

## Model download (in-container)

The model is **downloaded inside the container at startup**, not on the host — so the host needs no Python or Hugging Face CLI. On first start the entrypoint (`docker/entrypoint.sh`) runs `scripts/fetch_model.py`, which downloads `openbmb/VoxCPM2` into the bind-mounted model directory:

```text
$ASSET_ROOT\models\VoxCPM2
```

Because the directory is a bind mount, the weights persist on the host and stay out of the image layers. The download is skipped when the required files are already present, so restarts and `rebuild.ps1` do not re-download.

Downloads go through `huggingface_hub` with `hf-xet` acceleration enabled in the image (`HF_XET_HIGH_PERFORMANCE=1`). If `HF_Token` is set in `.env`, it is passed into the container as `HF_TOKEN` and used for authenticated downloads; otherwise the download is anonymous.

This behavior applies when `VOXCPM_MODEL_ID` is a local path (the default, `/models/VoxCPM2`). If you set `VOXCPM_MODEL_ID=openbmb/VoxCPM2`, the pre-download step is skipped and the application resolves/downloads the model at load time instead.

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

Use `VOXCPM_MODEL_ID=/models/VoxCPM2` for the model downloaded in-container into the bind mount (default). `HF_Token` is passed into the container as `HF_TOKEN` for authenticated downloads and should stay in the untracked `.env` file. To let the application resolve/download from Hugging Face at load time instead, set:

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

Validate the compose file:

```powershell
docker compose config
```

The container downloads the model on first start. Watch progress in the logs:

```powershell
docker compose -p voxcpm logs -f
```

Once the download finishes, confirm the main model exists on the host (substitute your `VOXCPM_ASSET_ROOT` value):

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

- The first in-container download can take a long time and requires enough free space under `VOXCPM_ASSET_ROOT`. The web UI only becomes reachable after it completes.
- If you need fully offline runtime, keep `VOXCPM_MODEL_ID=/models/VoxCPM2`; once downloaded, the model is reused from the bind mount.
- The Docker image does not include model weights. Rebuilding the image should not duplicate the large assets or re-download them.
