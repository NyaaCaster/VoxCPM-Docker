# HF Xet 下载工具

此目录用于本项目的 Hugging Face 官方客户端下载与 hf-xet 透明加速配置，不作为模型/数据集默认储存目录。

## 目录

- 项目根目录 `.env`：存放 Hugging Face token。建议使用 `HF_Token=hf_...`。
- `scripts\hf-env.ps1`：加载项目根目录 `.env`，按调用脚本时的当前工作目录设置 Hugging Face 缓存，并启用 `HF_XET_HIGH_PERFORMANCE=1`。
- `scripts\install-hf-tools.ps1`：安装/更新 `huggingface_hub[hf_xet]`。
- `scripts\hf-download.ps1`：使用官方 `hf download` 下载 repo/snapshot，自动带 token 和 hf-xet 高性能设置。

## 默认落盘规则

在哪里调用下载脚本，就把 Hugging Face 资源下载到哪里：

- `hf-download.ps1 <repo-id>` 默认下载到当前工作目录下的 `<repo-id安全化名称>\`。
- 缓存默认放在当前工作目录下的 `.hf-cache\`。
- 模型、数据集和缓存应跟随项目/目标存储位置存放，不要放到系统盘或工具目录。

如需指定目录，显式传入 `-LocalDir`。Docker/AI 大文件建议按规则放到 `E:\DockerRes\...`。

## .env 示例

```dotenv
HF_Token=hf_xxx
```

兼容变量名：`HF_TOKEN`、`HUGGINGFACE_TOKEN`、`HUGGING_FACE_HUB_TOKEN`、`ACCESS_TOKEN`、`HF_ACCESS_TOKEN`，但本项目推荐统一为 `HF_Token`。

## 首次安装

```powershell
hf-xet\scripts\install-hf-tools.ps1
```

## 下载整个模型 repo 到当前目录

```powershell
hf-xet\scripts\hf-download.ps1 Qwen/Qwen2.5-7B-Instruct
```

## 只下载指定文件类型到当前目录

```powershell
hf-xet\scripts\hf-download.ps1 Qwen/Qwen2.5-7B-Instruct -Include "*.safetensors" -Exclude "*.md"
```

## 下载 dataset 到当前目录

```powershell
hf-xet\scripts\hf-download.ps1 google/fleurs -RepoType dataset
```

## 下载到指定目录

```powershell
hf-xet\scripts\hf-download.ps1 Qwen/Qwen2.5-7B-Instruct -LocalDir "E:\DockerRes\hf-downloads\qwen\models"
```

## 说明

`HF_Token` 会被脚本标准化为 `HF_TOKEN`，再由 `huggingface_hub` 作为认证 token 使用。不要把 `.env` 提交到任何仓库。

Hugging Face Xet-backed 大文件必须通过 `hf download`/hf-xet 下载；本项目不再使用 aria2 直链下载 Hugging Face 文件，避免生成不完整或损坏的模型文件。
