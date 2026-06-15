$ErrorActionPreference = "Stop"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
  $python = Get-Command py -ErrorAction SilentlyContinue
}
if (-not $python) {
  throw "Python not found in PATH. Install Python first, then rerun this script."
}

& $python.Source -m pip install -U "huggingface_hub[hf_xet]"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Installed/updated huggingface_hub with hf-xet support."
Write-Host "Use: hf-xet\scripts\hf-download.ps1 <repo-id>"
