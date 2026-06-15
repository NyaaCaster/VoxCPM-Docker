---
name: docker-rebuild
description: Rebuild and restart the VoxCPM Docker container after changing the Dockerfile, docker-compose.yml, .env, application code, or dependencies. Use whenever the user asks to "重建/重新构建/rebuild/重启容器", apply Dockerfile or compose changes, or refresh the running image. Always use the project's rebuild.ps1 — never run ad-hoc docker commands that could touch other containers on the host.
---

# VoxCPM Docker Rebuild

本项目重建容器的标准流程。**必须用简体中文向用户汇报结果。**

## 唯一入口：rebuild.ps1

重建一律通过项目根目录的 `rebuild.ps1`，**不要**手敲零散的 `docker` 命令。脚本已固定 compose project 名 `voxcpm`，只会操作本项目的容器/网络/镜像，绝不误伤宿主机上其他容器。

```powershell
pwsh -NoProfile -File rebuild.ps1
```

脚本流程（顺序固定，勿跳步）：

1. `docker compose -p voxcpm down` —— 停止并移除旧容器
2. `docker compose -p voxcpm build` —— 重新构建镜像
3. 清理悬空镜像（`dangling=true`）—— 回收旧的无 tag 层，避免磁盘膨胀
4. `docker compose -p voxcpm up -d` —— 后台启动新容器
5. `docker ps` —— 打印运行状态供核对

## 何时需要 rebuild

- 改了 `Dockerfile`（如新增 apt 包、改基础镜像）→ **必须** rebuild，单纯 `up` 不会重建
- 改了应用代码 / `pyproject.toml` / 依赖 → 需要 rebuild
- 只改了 `.env` 或 `docker-compose.yml` 的环境变量/端口/挂载 → 通常 `docker compose -p voxcpm up -d` 即可生效，无需重新 build；不确定时直接跑 rebuild.ps1 最稳

## 重要约束

- **不重复下载模型**：模型权重和缓存是 `VOXCPM_ASSET_ROOT` 下的 bind mount，不在镜像里。rebuild 不碰它们。首次或换模型时才单独运行 `python scripts/download_models.py`。
- **悬空镜像清理只清 dangling**：脚本只删 `dangling=true` 的无 tag 镜像，不会动其他项目的有 tag 镜像。
- **GPU 模式**：compose 默认请求 NVIDIA GPU。若环境无 GPU，先在 `.env` 设 `VOXCPM_DEVICE=cpu` 并按需注释 compose 的 `deploy` 块，再 rebuild。

## 验证

启动后确认：

```powershell
docker compose -p voxcpm logs --tail 50 voxcpm   # 应看到 Gradio 监听 0.0.0.0:8808
docker compose -p voxcpm exec voxcpm date         # 验证时区为上海时间（TZ=Asia/Shanghai + tzdata）
```

Web UI：`http://localhost:5106`（容器内 8808，宿主默认映射 5106）。

## Windows 会话注意

若 `docker` 命令报 `A specified logon session does not exist` 或 credential helper 错误，按用户级 skill `windows-user-session-runner` 处理，不要在 `credsStore` 上反复折腾。
