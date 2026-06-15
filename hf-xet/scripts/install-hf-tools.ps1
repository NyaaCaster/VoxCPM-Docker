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

# Confirm the 'hf' CLI is actually reachable. Store/user pip installs land it in
# a Scripts dir that is not on PATH, so report the resolved path (or a hint).
. "$PSScriptRoot\hf-path.ps1"
$hfPath = Resolve-HfCommand -PythonExe $python.Source
if ($hfPath) {
  Write-Host "hf CLI located: $hfPath"
} else {
  Write-Warning "hf CLI was installed but could not be located. Reopen the terminal or add Python's Scripts directory to PATH."
}
Write-Host "Use: hf-xet\scripts\hf-download.ps1 <repo-id>"
