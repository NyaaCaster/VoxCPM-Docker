# VoxCPM — 项目级说明

本项目以单一 Gradio 服务的形式通过 Docker 部署。与用户的所有对话使用**简体中文**。

## Docker 重建（MUST）

需要重建或重启容器时（改动 `Dockerfile`、`docker-compose.yml`、`.env`、应用代码或依赖后），**一律使用项目根目录的 `rebuild.ps1`**，不要手敲零散的 `docker` 命令。详见项目级 skill `docker-rebuild`（`.claude/skills/docker-rebuild/SKILL.md`）。

```powershell
pwsh -NoProfile -File rebuild.ps1
```

`rebuild.ps1` 固定了 compose project 名 `voxcpm`，流程为 down → build → 清理悬空镜像 → up -d → 显示状态，只操作本项目资源，不影响宿主机其他容器。

## 首次部署

全新环境的首次部署使用交互式 `FirstBuild.ps1`：引导生成 `.env`（端口 / 大文件路径 / HF token）→ 构建并启动容器 → 打印访问地址。模型在容器**首次启动时于容器内自动下载**到 bind mount，无需宿主机 Python 或 `hf` CLI。提示支持中英双语，脚本以 UTF-8 带 BOM 保存以保证 PowerShell 5.1 下中文不乱码；生成的 `.env` 为 UTF-8 无 BOM 的纯键值对。`FirstBuild.ps1` 用于初始化，`rebuild.ps1` 用于此后的迭代重建。

## 配置唯一来源（SSOT）

- 所有可调参数集中在 `.env`，每项在 `docker-compose.yml` 中都有默认值兜底，无需手动编辑 compose 文件。
- `.env` 不含注释；注释与文档说明只保留在 `.env.example`。
- `VOXCPM_ASSET_ROOT` 是宿主机大文件资产目录的唯一真实来源，由 compose 和 `scripts/download_models.py` 共同取用。模型、缓存、输出等大文件均为该目录下的 bind mount，不进镜像层。
- 时区由 `.env` 的 `TZ`（默认 `Asia/Shanghai`）控制，Dockerfile 已安装 `tzdata` 使其生效。

## 模型资产

- 模型权重由**容器自身**在启动时下载（`docker/entrypoint.sh` → `scripts/fetch_model.py`），写入 bind mount 的 `${VOXCPM_ASSET_ROOT}/models/VoxCPM2`，**与镜像层解耦**，rebuild 不会重复下载（已存在即跳过）。
- 下载在容器内通过 `huggingface_hub`（启用 `hf-xet` 加速）完成，不依赖宿主机的 Python 或 `hf` CLI。`.env` 的 `HF_Token` 经 compose 以 `HF_TOKEN` 传入容器用于认证/加速。
