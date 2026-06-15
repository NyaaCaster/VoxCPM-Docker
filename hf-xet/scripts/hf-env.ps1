param(
  [string]$EnvPath,
  [string]$WorkDir = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
if (-not $EnvPath) {
  $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $EnvPath = Join-Path $projectRoot ".env"
}

function Set-DotEnvValue {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $clean = $Value.Trim()
  if (($clean.StartsWith('"') -and $clean.EndsWith('"')) -or ($clean.StartsWith("'") -and $clean.EndsWith("'"))) {
    $clean = $clean.Substring(1, $clean.Length - 2)
  }
  [Environment]::SetEnvironmentVariable($Name, $clean, "Process")
}

if (-not (Test-Path $EnvPath)) {
  throw ".env file not found: $EnvPath"
}

Get-Content $EnvPath | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith('#')) { return }
  $pair = $line -split '=', 2
  if ($pair.Count -ne 2) { return }
  Set-DotEnvValue -Name $pair[0].Trim() -Value $pair[1]
}

# Accept common token names, but standardize on HF_TOKEN for huggingface_hub.
if (-not $env:HF_TOKEN) {
  if ($env:HF_Token) { $env:HF_TOKEN = $env:HF_Token }
  elseif ($env:HUGGINGFACE_TOKEN) { $env:HF_TOKEN = $env:HUGGINGFACE_TOKEN }
  elseif ($env:HUGGING_FACE_HUB_TOKEN) { $env:HF_TOKEN = $env:HUGGING_FACE_HUB_TOKEN }
  elseif ($env:ACCESS_TOKEN) { $env:HF_TOKEN = $env:ACCESS_TOKEN }
  elseif ($env:HF_ACCESS_TOKEN) { $env:HF_TOKEN = $env:HF_ACCESS_TOKEN }
}

$cacheRoot = Join-Path $WorkDir ".hf-cache"
$env:HF_HOME = Join-Path $cacheRoot "home"
$env:HF_HUB_CACHE = Join-Path $cacheRoot "hub"
$env:HF_XET_CACHE = Join-Path $cacheRoot "xet"
$env:HF_ASSETS_CACHE = Join-Path $cacheRoot "assets"
$env:HF_XET_HIGH_PERFORMANCE = "1"

foreach ($dir in @($env:HF_HOME, $env:HF_HUB_CACHE, $env:HF_XET_CACHE, $env:HF_ASSETS_CACHE)) {
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
}

if (-not $env:HF_TOKEN) {
  Write-Warning "No HF token found. Put HF_Token=... or HF_TOKEN=... in $EnvPath."
}

Write-Host "HF environment loaded. Token present: $([bool]$env:HF_TOKEN). HF_XET_HIGH_PERFORMANCE=$env:HF_XET_HIGH_PERFORMANCE"
Write-Host "WorkDir=$WorkDir"
Write-Host "HF_HOME=$env:HF_HOME"
Write-Host "HF_HUB_CACHE=$env:HF_HUB_CACHE"
Write-Host "HF_XET_CACHE=$env:HF_XET_CACHE"
