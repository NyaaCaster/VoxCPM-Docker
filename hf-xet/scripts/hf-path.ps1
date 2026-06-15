# hf-path.ps1 - Locate the Hugging Face CLI ('hf') even when pip installed it
# into a Python Scripts directory that is not on PATH.
#
# Microsoft Store Python (and any --user install) drops console scripts such as
# hf.exe into a per-user Scripts folder that Windows does NOT add to PATH, so a
# plain `Get-Command hf` fails even though the package installed correctly.
# Worse, Store Python redirects pip's user installs into
#   ...\LocalCache\local-packages\pythonXXX\site-packages
# while sysconfig's nt_user scheme still reports %APPDATA%\Roaming\Python\...,
# so probing by scheme alone misses the real location.
#
# The robust approach is to ask the installed huggingface_hub package where it
# lives and derive the sibling Scripts directory from that, in addition to the
# scheme-based and interpreter-relative candidates.
#
# Usage: dot-source this file, then call Resolve-HfCommand. When the CLI is
# found in a non-PATH location, its directory is prepended to $env:PATH so that
# child processes (python / powershell) inherit it.

function Get-PythonScriptDirs {
    param([string]$PythonExe = "python")

    # Emit every plausible Scripts directory. The most reliable signal is the
    # location of an already-installed package (huggingface_hub), from which the
    # Scripts dir is derived; scheme-based and exe-relative candidates are added
    # as fallbacks. Only directories that actually exist are printed.
    $probe = @'
import os, sys, sysconfig, site
out = []
def add(p):
    if p and p not in out:
        out.append(p)
def from_sitepackages(sp):
    # venv:  <prefix>/Lib/site-packages -> <prefix>/Scripts  (two levels up)
    # store: <...>/pythonXXX/site-packages -> <...>/pythonXXX/Scripts (one level up)
    if not sp:
        return
    add(os.path.join(os.path.dirname(sp), "Scripts"))
    add(os.path.join(os.path.dirname(os.path.dirname(sp)), "Scripts"))

# 1. Derive from the installed huggingface_hub package itself (most reliable).
try:
    import huggingface_hub
    pkg = os.path.dirname(os.path.abspath(huggingface_hub.__file__))  # .../site-packages/huggingface_hub
    from_sitepackages(os.path.dirname(pkg))                          # .../site-packages
except Exception:
    pass

# 2. User and global site-packages reported by the site module.
try:
    usp = site.getusersitepackages()
    for p in ([usp] if isinstance(usp, str) else list(usp)):
        from_sitepackages(p)
except Exception:
    pass
try:
    for p in site.getsitepackages():
        from_sitepackages(p)
except Exception:
    pass

# 3. sysconfig schemes.
schemes = ["nt_user"]
try:
    schemes.append(sysconfig.get_default_scheme())
except Exception:
    pass
schemes.append("nt")
for scheme in dict.fromkeys(schemes):
    try:
        add(sysconfig.get_path("scripts", scheme))
    except Exception:
        pass

# 4. User base Scripts and a dir next to the interpreter.
try:
    add(os.path.join(site.getuserbase(), "Scripts"))
except Exception:
    pass
add(os.path.join(os.path.dirname(os.path.abspath(sys.executable)), "Scripts"))

for p in out:
    if p and os.path.isdir(p):
        print(p)
'@

    try {
        & $PythonExe -c $probe 2>$null
    } catch {
        @()
    }
}

function Resolve-HfCommand {
    # Returns the full path to the hf executable, prepending its directory to
    # $env:PATH so child processes inherit it. Returns $null if not found.
    # On failure, the probed directories are stashed in $script:HfProbedDirs
    # so callers can print a useful diagnostic.
    param([string]$PythonExe = "python")

    $existing = Get-Command hf -ErrorAction SilentlyContinue
    if ($existing) { return $existing.Source }

    $dirs = @(Get-PythonScriptDirs -PythonExe $PythonExe)
    $script:HfProbedDirs = $dirs
    foreach ($dir in $dirs) {
        foreach ($name in @("hf.exe", "hf.cmd", "hf.bat", "hf")) {
            $candidate = Join-Path $dir $name
            if (Test-Path -LiteralPath $candidate) {
                if (($env:PATH -split ';') -notcontains $dir) {
                    $env:PATH = "$dir;$env:PATH"
                }
                return $candidate
            }
        }
    }
    return $null
}

function Write-HfProbeDiagnostic {
    # Print the directories that were probed for the hf CLI, to aid debugging
    # when Resolve-HfCommand returns $null.
    param([string]$PythonExe = "python")

    $dirs = $script:HfProbedDirs
    if (-not $dirs) { $dirs = @(Get-PythonScriptDirs -PythonExe $PythonExe) }
    Write-Host "Probed these Python Scripts directories for 'hf':" -ForegroundColor DarkGray
    if ($dirs.Count -eq 0) {
        Write-Host "  (none found)" -ForegroundColor DarkGray
    } else {
        foreach ($dir in $dirs) { Write-Host "  $dir" -ForegroundColor DarkGray }
    }
}
