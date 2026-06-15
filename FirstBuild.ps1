#Requires -Version 5.1
<#
  FirstBuild.ps1 - One-click initial deployment for VoxCPM (interactive).
  VoxCPM 一键初始部署脚本（交互式）。

  Flow / 流程:
    1. Generate .env from .env.example (port / asset path / HF token)
    2. Pre-download the model with live progress
    3. docker compose build + up -d with live progress
    4. Print the local URL to open the web UI

  Run from anywhere; it operates on its own project directory.
#>

$ErrorActionPreference = "Stop"

# --- Console encoding so Chinese text renders correctly / 中文编码适配 ---
try {
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch { }

# Operate on the script's own directory regardless of caller location.
Set-Location -LiteralPath $PSScriptRoot

$PROJECT       = "voxcpm"
$ENV_EXAMPLE   = Join-Path $PSScriptRoot ".env.example"
$ENV_FILE      = Join-Path $PSScriptRoot ".env"
$COMPOSE_FILE  = Join-Path $PSScriptRoot "docker-compose.yml"
$DOWNLOAD_PY   = Join-Path $PSScriptRoot "scripts\download_models.py"
$DEFAULT_PORT  = 8808

# ---------------------------------------------------------------------------
# Bilingual helpers / 双语辅助
# ---------------------------------------------------------------------------
$script:Lang = "en"
function L([string]$en, [string]$zh) { if ($script:Lang -eq "zh") { $zh } else { $en } }
function Info([string]$en, [string]$zh) { Write-Host (L $en $zh) -ForegroundColor Cyan }
function Ok([string]$en, [string]$zh)   { Write-Host (L $en $zh) -ForegroundColor Green }
function Warn([string]$en, [string]$zh) { Write-Host (L $en $zh) -ForegroundColor Yellow }
function Step([int]$n, [string]$en, [string]$zh) {
    Write-Host ""
    Write-Host ("=" * 64) -ForegroundColor DarkGray
    Write-Host (L "[$n/4] $en" "[$n/4] $zh") -ForegroundColor Magenta
    Write-Host ("=" * 64) -ForegroundColor DarkGray
}
function Fail([string]$en, [string]$zh) {
    Write-Host ""
    Write-Host (L "ERROR: $en" "错误：$zh") -ForegroundColor Red
    exit 1
}
function AskYesNo([string]$en, [string]$zh) {
    # Default No. Returns $true only on an explicit yes.
    $ans = Read-Host (L "$en [y/N]" "$zh [y/N]")
    return ($ans.Trim() -match '^(y|yes)$')
}

# ---------------------------------------------------------------------------
# Language selection / 语言选择
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  VoxCPM - First Build / 一键初始部署" -ForegroundColor White
Write-Host "  ----------------------------------" -ForegroundColor DarkGray
Write-Host "  Select language / 选择语言:"
Write-Host "    [1] English"
Write-Host "    [2] 中文 (Chinese)"
$sel = Read-Host "  Enter 1 or 2 (default 1) / 输入 1 或 2（默认 1）"
if ($sel.Trim() -eq "2") { $script:Lang = "zh" } else { $script:Lang = "en" }

# ---------------------------------------------------------------------------
# Prerequisite checks / 前置检查
# ---------------------------------------------------------------------------
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail "Docker is not installed or not in PATH." "未检测到 Docker，请先安装并确保其在 PATH 中。"
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Fail "Python is not installed or not in PATH (needed for model download)." "未检测到 Python（下载模型需要），请先安装并确保其在 PATH 中。"
}
if (-not (Test-Path -LiteralPath $ENV_EXAMPLE)) {
    Fail ".env.example not found next to this script." "脚本同目录下未找到 .env.example。"
}

# ===========================================================================
# Step 1: Build .env from .env.example / 由 .env.example 生成 .env
# ===========================================================================
Step 1 "Configure environment (.env)" "配置环境变量（.env）"

if (Test-Path -LiteralPath $ENV_FILE) {
    if (-not (AskYesNo ".env already exists. Overwrite it?" "检测到 .env 已存在，是否覆盖？")) {
        Warn "Keeping the existing .env. Skipping configuration." "保留现有 .env，跳过配置步骤。"
        $skipEnv = $true
    }
}

if (-not $skipEnv) {
    # Parse .env.example into an ordered key/value list, dropping comments/blanks.
    # 解析 .env.example 为有序键值对，丢弃注释与空行（生成的 .env 不含注释）。
    $pairs = [System.Collections.Specialized.OrderedDictionary]::new()
    foreach ($raw in Get-Content -LiteralPath $ENV_EXAMPLE -Encoding UTF8) {
        $line = $raw.Trim()
        if ($line -eq "" -or $line.StartsWith("#") -or ($line -notmatch "=")) { continue }
        $k, $v = $line.Split("=", 2)
        $pairs[$k.Trim()] = $v.Trim()
    }

    # --- Port / 端口 ---
    Info "The container serves the web UI on the default port $DEFAULT_PORT." `
         "容器默认使用 $DEFAULT_PORT 端口提供前端页面。"
    $port = $DEFAULT_PORT
    if (AskYesNo "Use a custom host port instead?" "是否要自定义映射到主机的端口？") {
        while ($true) {
            $p = Read-Host (L "Enter port number (1-65535)" "请输入端口号（1-65535）")
            if ($p -match '^\d+$' -and [int]$p -ge 1 -and [int]$p -le 65535) { $port = [int]$p; break }
            Warn "Invalid port, please try again." "端口无效，请重新输入。"
        }
    }
    Ok "Host port set to $port." "主机端口已设为 $port。"
    $pairs["VOXCPM_HOST_PORT"] = "$port"

    # --- Asset root / 大文件存放路径 ---
    Info "By default, models and caches are stored under the project directory." `
         "默认情况下，模型与缓存存放在项目目录下。"
    if (AskYesNo "Store large files (models/caches) in a different path?" "是否要将模型等大文件存放到其他路径？") {
        $path = Read-Host (L "Enter target directory (e.g. E:\DockerRes\VoxCPM)" "请输入目标目录（例如 E:\DockerRes\VoxCPM）")
        $path = $path.Trim().Trim('"').Trim("'")
        # Normalize: backslashes -> forward slashes; strip trailing slash(es).
        # 路径规整：反斜杠转正斜杠；去掉结尾的斜杠；保留盘符根。
        $path = $path -replace '\\', '/'
        $path = $path -replace '/+$', ''
        if ($path -match '^[A-Za-z]:$') { $path = "$path/" }
        if ($path -eq "") { $path = "." }
        $pairs["VOXCPM_ASSET_ROOT"] = $path
        Ok "Asset root set to $path." "大文件路径已设为 $path。"
    } else {
        if (-not $pairs.Contains("VOXCPM_ASSET_ROOT") -or $pairs["VOXCPM_ASSET_ROOT"] -eq "") {
            $pairs["VOXCPM_ASSET_ROOT"] = "."
        }
        Ok "Using project directory for large files." "大文件将存放在项目目录下。"
    }

    # --- Hugging Face token / HF 访问令牌 ---
    Info "A Hugging Face Access Token enables transparent acceleration when downloading models." `
         "Hugging Face 访问令牌可在下载模型时提供透明加速。"
    Info "Generate one at: https://huggingface.co/settings/tokens" `
         "请前往 https://huggingface.co/settings/tokens 生成 Access Token。"
    $tok = Read-Host (L "Paste your HF Access Token (leave empty to skip)" "请粘贴你的 HF Access Token（可留空跳过）")
    $pairs["HF_Token"] = $tok.Trim()
    if ($pairs["HF_Token"] -ne "") { Ok "Token recorded." "令牌已记录。" }
    else { Warn "No token provided; downloads will use anonymous access." "未提供令牌；将使用匿名方式下载。" }

    # Write .env as plain key=value, UTF-8 without BOM (dotenv standard).
    # 写出纯键值对 .env，UTF-8 无 BOM（dotenv 标准）。
    $sb = [System.Text.StringBuilder]::new()
    foreach ($key in $pairs.Keys) { [void]$sb.AppendLine("$key=$($pairs[$key])") }
    [System.IO.File]::WriteAllText($ENV_FILE, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
    Ok ".env written successfully." ".env 已成功生成。"
}

# ===========================================================================
# Step 2: Download model / 下载模型
# ===========================================================================
Step 2 "Download model (live progress)" "下载模型（实时进度）"
Info "Pre-downloading the VoxCPM model. This may take a while on first run..." `
     "正在预下载 VoxCPM 模型，首次运行可能耗时较长……"

if (-not (Test-Path -LiteralPath $DOWNLOAD_PY)) {
    Fail "scripts/download_models.py not found." "未找到 scripts/download_models.py。"
}

# Run in the foreground so download progress streams live to the console.
# 前台运行，使下载进度实时刷新到终端。
python $DOWNLOAD_PY
if ($LASTEXITCODE -ne 0) {
    Fail "Model download failed (exit code $LASTEXITCODE)." "模型下载失败（退出码 $LASTEXITCODE）。"
}
Ok "Model downloaded." "模型下载完成。"

# ===========================================================================
# Step 3: Build and start containers / 构建并启动容器
# ===========================================================================
Step 3 "Build and start containers (live progress)" "构建并启动容器（实时进度）"

Info "Building the Docker image..." "正在构建 Docker 镜像……"
docker compose -p $PROJECT -f $COMPOSE_FILE build
if ($LASTEXITCODE -ne 0) {
    Fail "docker compose build failed (exit code $LASTEXITCODE)." "镜像构建失败（退出码 $LASTEXITCODE）。"
}

Info "Starting the container in the background..." "正在后台启动容器……"
docker compose -p $PROJECT -f $COMPOSE_FILE up -d
if ($LASTEXITCODE -ne 0) {
    Fail "docker compose up failed (exit code $LASTEXITCODE)." "容器启动失败（退出码 $LASTEXITCODE）。"
}
Ok "Container is up." "容器已启动。"

# ===========================================================================
# Step 4: Done / 完成
# ===========================================================================
# Resolve the final host port from .env for the URL.
# 从 .env 读取最终端口用于访问地址。
$finalPort = $DEFAULT_PORT
if (Test-Path -LiteralPath $ENV_FILE) {
    foreach ($raw in Get-Content -LiteralPath $ENV_FILE -Encoding UTF8) {
        if ($raw -match '^\s*VOXCPM_HOST_PORT\s*=\s*(\d+)') { $finalPort = $Matches[1]; break }
    }
}

Step 4 "Deployment complete" "部署完成"
Ok "VoxCPM is ready!" "VoxCPM 已就绪！"
Write-Host ""
Write-Host (L "  Open the web UI at: " "  请在浏览器中访问： ") -NoNewline -ForegroundColor White
Write-Host ("http://localhost:{0}" -f $finalPort) -ForegroundColor Green
Write-Host ""
Info "Useful commands:" "常用命令："
Write-Host ("  docker compose -p {0} logs -f      " -f $PROJECT) -NoNewline -ForegroundColor DarkGray
Write-Host (L "# view logs" "# 查看日志")
Write-Host ("  docker compose -p {0} down          " -f $PROJECT) -NoNewline -ForegroundColor DarkGray
Write-Host (L "# stop and remove" "# 停止并移除")
Write-Host ("  pwsh -NoProfile -File rebuild.ps1   ") -NoNewline -ForegroundColor DarkGray
Write-Host (L "# rebuild after changes" "# 改动后重建")
