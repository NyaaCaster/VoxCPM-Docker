# VoxCPM-Docker

[English](./README_EN.md) | **中文**

使用 Docker Compose 快速部署 [VoxCPM](https://github.com/OpenBMB/VoxCPM/)。

本仓库**仅**是 VoxCPM 的 Docker Compose 部署封装，把模型打包成单一 Gradio 网页服务，让你一条命令即可运行，无需手动配置 Python、CUDA 或依赖。关于 VoxCPM 本身——它是什么、模型能力、库的用法、模型许可——请参见上游项目：**https://github.com/OpenBMB/VoxCPM/**

## 前置条件

- **Docker**（含 Compose 插件）。Windows 上若需 GPU 加速，使用 Docker Desktop 的 WSL2 后端并确保 NVIDIA 容器支持可用。
- 宿主机安装 **Python**（仅用于模型预下载步骤）。
- **Hugging Face Access Token**——两种部署方式都需要它来加速模型下载。请前往 **https://huggingface.co/settings/tokens** 生成，并在开始前准备好。

## 首次部署

首次部署有两种方式，**均需提前准备 Hugging Face Access Token**。

### 方式一 —— 自动部署（推荐）

运行交互式一键脚本。它会以中英双语提示你输入主机端口、大文件存放路径和 Access Token，随后**自动创建 `.env`、下载模型、构建镜像并启动容器**。

```powershell
pwsh -NoProfile -File FirstBuild.ps1
```

脚本结束时会打印访问地址，整个部署即告完成。

### 方式二 —— 手动部署

自行根据模板创建 `.env` 再启动 Compose：

1. 复制示例文件：

   ```powershell
   Copy-Item .env.example .env
   ```

2. 编辑 `.env`，配置：
   - `HF_Token`—— 你的 Hugging Face Access Token（加速下载所需）。
   - `VOXCPM_HOST_PORT`—— 网页界面的主机端口（容器内部监听 `8808`）。
   - `VOXCPM_ASSET_ROOT`—— 模型、缓存、输出等大体积文件的存放路径。请指向空间充足的磁盘，例如 `E:/DockerRes/VoxCPM`；默认为项目目录。

3. 预下载模型，然后构建并启动：

   ```powershell
   python scripts/download_models.py
   docker compose up --build -d
   ```

完整的手动参考（目录结构、GPU/CPU 模式、验证）见 [DOCKER.md](./DOCKER.md)。

## 访问网页界面

部署完成后，在浏览器打开：

```text
http://localhost:<VOXCPM_HOST_PORT>
```

未修改时默认端口为 `8808`。

## 改动后的重建

部署完成后，此后任何重建（修改 `Dockerfile`、`docker-compose.yml`、`.env` 或应用代码后）一律使用 `rebuild.ps1`。它会停止、重建、清理悬空镜像并重启，且只操作本项目的容器。

```powershell
pwsh -NoProfile -File rebuild.ps1
```

`FirstBuild.ps1` 用于首次初始化，`rebuild.ps1` 用于此后的迭代重建。

## 配置说明

所有可调参数集中在 `.env`（唯一真实来源）；`docker-compose.yml` 为每项提供默认值，无需手动编辑。注释与文档说明保留在 `.env.example`。最重要的是 `VOXCPM_ASSET_ROOT`——宿主机大文件资产目录，这些文件以 bind mount 形式挂载，不进镜像层。

## 许可

本仓库的部署脚本以 Apache-2.0 许可发布，与上游 VoxCPM 一致。VoxCPM 模型与代码遵循其上游各自的许可，详见[上游项目](https://github.com/OpenBMB/VoxCPM/)。
