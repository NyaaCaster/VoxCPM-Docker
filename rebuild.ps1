$ErrorActionPreference = "Stop"
$COMPOSE_FILE = "docker-compose.yml"
$PROJECT = "voxcpm"

# Rebuild the VoxCPM image and run the container locally — no registry tag/push.
# `-p $PROJECT` pins the compose project name so this only ever touches this
# project's container/network, never the other containers on the host.
#
# Large assets (models, caches, data, outputs) live under VOXCPM_ASSET_ROOT as
# bind mounts and are NOT part of the image. The container downloads the model
# into that bind mount on first start and skips it when already present, so this
# script never re-downloads the weights.

# Run from the script's own directory so relative paths (.env, compose) resolve
# regardless of the caller's current location.
Set-Location -LiteralPath $PSScriptRoot

Write-Host "Stopping containers..." -ForegroundColor Cyan
docker compose -p $PROJECT -f $COMPOSE_FILE down

Write-Host "Building image..." -ForegroundColor Cyan
docker compose -p $PROJECT -f $COMPOSE_FILE build

Write-Host "Removing dangling images..." -ForegroundColor Cyan
$dangling = docker images -f "dangling=true" -q
if ($dangling) { docker rmi -f $dangling }

Write-Host "Starting containers..." -ForegroundColor Cyan
docker compose -p $PROJECT -f $COMPOSE_FILE up -d

Write-Host "Done. Running containers:" -ForegroundColor Green
docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
