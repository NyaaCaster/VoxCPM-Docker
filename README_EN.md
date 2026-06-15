# VoxCPM-Docker

**English** | [中文](./README.md)

Deploy [VoxCPM](https://github.com/OpenBMB/VoxCPM/) quickly with Docker Compose.

This repository is **only** a Docker Compose deployment wrapper for VoxCPM. It packages the model as a single Gradio web service so you can run it with one command, without setting up Python, CUDA, or dependencies by hand. For everything about VoxCPM itself — what it is, model capabilities, usage of the library, and licensing of the model — see the upstream project: **https://github.com/OpenBMB/VoxCPM/**

## Prerequisites

- **Docker** with the Compose plugin. For GPU acceleration on Windows, use Docker Desktop with the WSL2 backend and working NVIDIA container support.
- **Python** on the host (used only by the model pre-download step).
- A **Hugging Face Access Token** — required by both deployment methods to accelerate model downloads. Generate one at **https://huggingface.co/settings/tokens** and have it ready before you start.

## Get the code

Clone this repository and enter the project directory (all later commands run from there):

```powershell
git clone https://github.com/NyaaCaster/VoxCPM-Docker.git
cd VoxCPM-Docker
```

## First-time deployment

There are two ways to do the initial setup. Both need your Hugging Face Access Token.

### Option A — Automatic (recommended)

Run the interactive one-click script. It prompts you (in English or Chinese) for the host port, the large-file storage path, and your Access Token, then **creates `.env` automatically, downloads the model, builds the image, and starts the container**.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File FirstBuild.ps1
```

When it finishes it prints the URL to open. That's the whole setup.

### Option B — Manual

Create `.env` yourself from the template and start Compose:

1. Copy the example file:

   ```powershell
   Copy-Item .env.example .env
   ```

2. Edit `.env` and set:
   - `HF_Token` — your Hugging Face Access Token (required for accelerated downloads).
   - `VOXCPM_HOST_PORT` — the host port for the web UI (the container listens on `8808`).
   - `VOXCPM_ASSET_ROOT` — where to store large files (models, caches, outputs). Point this at a drive with enough free space, e.g. `E:/DockerRes/VoxCPM`. It defaults to the project directory.

3. Pre-download the model, then build and start:

   ```powershell
   python scripts/download_models.py
   docker compose up --build -d
   ```

See [DOCKER.md](./DOCKER.md) for the full manual reference (directory layout, GPU/CPU modes, verification).

## Open the web UI

After deployment, open:

```text
http://localhost:<VOXCPM_HOST_PORT>
```

The default port is `8808` unless you changed it.

## Rebuilding after changes

Once deployed, use `rebuild.ps1` for any later rebuild (after editing the `Dockerfile`, `docker-compose.yml`, `.env`, or app code). It stops, rebuilds, prunes dangling images, and restarts — touching only this project's container.

```powershell
pwsh -NoProfile -File rebuild.ps1
```

`FirstBuild.ps1` is for the initial setup; `rebuild.ps1` is for iterating afterwards.

## Configuration

All tunables live in `.env` (single source of truth); `docker-compose.yml` provides a default for each, so it needs no manual editing. Comments and documentation live in `.env.example`. The most important value is `VOXCPM_ASSET_ROOT`, the host directory for large bind-mounted assets that stay out of the Docker image.

## License

The deployment scripts in this repository are provided under the Apache-2.0 license, matching upstream VoxCPM. The VoxCPM model and code are governed by their own upstream license — see the [upstream project](https://github.com/OpenBMB/VoxCPM/).
