param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$RepoId,

  [ValidateSet('model', 'dataset', 'space')]
  [string]$RepoType = 'model',

  [string]$Revision,
  [string[]]$Include,
  [string[]]$Exclude,
  [string]$LocalDir,
  [int]$MaxWorkers = 8,
  [switch]$DryRun,
  [switch]$ForceDownload,
  [string]$EnvPath
)

$ErrorActionPreference = "Stop"
if (-not $EnvPath) {
  $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  $EnvPath = Join-Path $projectRoot ".env"
}
$workDir = (Get-Location).Path
. "$PSScriptRoot\hf-env.ps1" -EnvPath $EnvPath -WorkDir $workDir

$hf = Get-Command hf -ErrorAction SilentlyContinue
if (-not $hf) {
  throw "Hugging Face CLI 'hf' not found. Run hf-xet\scripts\install-hf-tools.ps1 first."
}

if (-not $LocalDir) {
  $safeRepo = $RepoId -replace '[\\/:*?"<>|]', '_'
  $LocalDir = Join-Path $workDir $safeRepo
}
if (-not (Test-Path $LocalDir)) { New-Item -ItemType Directory -Path $LocalDir | Out-Null }

$argsList = @('download', $RepoId, '--local-dir', $LocalDir, '--cache-dir', $env:HF_HUB_CACHE, '--max-workers', $MaxWorkers.ToString())
if ($RepoType -ne 'model') { $argsList += @('--repo-type', $RepoType) }
if ($Revision) { $argsList += @('--revision', $Revision) }
foreach ($pattern in ($Include | Where-Object { $_ })) { $argsList += @('--include', $pattern) }
foreach ($pattern in ($Exclude | Where-Object { $_ })) { $argsList += @('--exclude', $pattern) }
if ($DryRun) { $argsList += '--dry-run' }
if ($ForceDownload) { $argsList += '--force-download' }
if ($env:HF_TOKEN) { $argsList += @('--token', $env:HF_TOKEN) }

Write-Host "Running: hf download $RepoId -> $LocalDir"
Write-Host "Xet high performance: $env:HF_XET_HIGH_PERFORMANCE; cache: $env:HF_HUB_CACHE"
& $hf.Source @argsList
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
