# VoxCPM-Docker

[English](./README_EN.md) | **中文**

使用 Docker Compose 快速部署 [VoxCPM](https://github.com/OpenBMB/VoxCPM/)。

本仓库**仅**是 VoxCPM 的 Docker Compose 部署封装，把模型打包成单一 Gradio 网页服务，让你一条命令即可运行，无需手动配置 Python、CUDA 或依赖。关于 VoxCPM 本身——它是什么、模型能力、库的用法、模型许可——请参见上游项目：**https://github.com/OpenBMB/VoxCPM/**

## 前置条件

- **Docker**（含 Compose 插件）。Windows 上若需 GPU 加速，使用 Docker Desktop 的 WSL2 后端并确保 NVIDIA 容器支持可用。
- **Hugging Face Access Token**（可选但推荐）——用于加速并认证模型下载。请前往 **https://huggingface.co/settings/tokens** 生成。模型在容器内下载，宿主机**无需**安装 Python 或 Hugging Face CLI。

## 获取代码

克隆本仓库并进入项目目录（后续所有命令都在该目录下执行）：

```powershell
git clone https://github.com/NyaaCaster/VoxCPM-Docker.git
cd VoxCPM-Docker
```

## 首次部署

首次部署有两种方式。准备好 Hugging Face Access Token 可加速下载（可选）。

### 方式一 —— 自动部署（推荐）

运行交互式一键脚本。它会以中英双语提示你输入主机端口、大文件存放路径和 Access Token，随后**自动创建 `.env`、构建镜像并启动容器**。模型在容器**首次启动时于容器内自动下载**。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File FirstBuild.ps1
```

脚本结束时会打印访问地址。注意首次启动时容器需先下载模型，网页界面稍后才可访问；可用 `docker compose -p voxcpm logs -f` 查看下载进度。

### 方式二 —— 手动部署

自行根据模板创建 `.env` 再启动 Compose：

1. 复制示例文件：

   ```powershell
   Copy-Item .env.example .env
   ```

2. 编辑 `.env`，配置：
   - `HF_Token`—— 你的 Hugging Face Access Token（加速/认证下载所需，可留空匿名下载）。
   - `VOXCPM_HOST_PORT`—— 网页界面的主机端口（容器内部监听 `8808`）。
   - `VOXCPM_ASSET_ROOT`—— 模型、缓存、输出等大体积文件的存放路径。请指向空间充足的磁盘，例如 `E:/DockerRes/VoxCPM`；默认为项目目录。

3. 构建并启动（模型会在容器首次启动时自动下载到 bind mount）：

   ```powershell
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
