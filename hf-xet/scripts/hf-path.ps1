# hf-path.ps1 - Locate the Hugging Face CLI ('hf') even when pip installed it
# into a Python user/Store Scripts directory that is not on PATH.
#
# Microsoft Store Python (and any --user install) drops console scripts such as
# hf.exe into a per-user Scripts folder that Windows does NOT add to PATH, so a
# plain `Get-Command hf` fails even though the package installed correctly.
#
# Usage: dot-source this file, then call Resolve-HfCommand. When the CLI is
# found in a non-PATH location, its directory is prepended to $env:PATH so that
# child processes (python / powershell) inherit it.

function Get-PythonScriptDirs {
    param([string]$PythonExe = "python")

    # Ask Python where pip would have placed console scripts. Covers Store/user
    # installs (nt_user), the active scheme, the global scheme, and a fallback
    # next to the interpreter. Only existing directories are returned.
    $probe = @'
import os, sys, sysconfig, site
out = []
def add(p):
    if p and p not in out:
        out.append(p)
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
    param([string]$PythonExe = "python")

    $existing = Get-Command hf -ErrorAction SilentlyContinue
    if ($existing) { return $existing.Source }

    foreach ($dir in (Get-PythonScriptDirs -PythonExe $PythonExe)) {
        foreach ($name in @("hf.exe", "hf.cmd", "hf")) {
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
