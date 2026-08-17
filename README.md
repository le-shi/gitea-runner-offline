# gitea-runner-offline

从 `gitea/runner:3.0` 提取官方 Runner 二进制和启动脚本，并以 `debian:bookworm-slim` 作为最终运行层构建的离线增强镜像，面向无公网或网络不稳定环境。GitHub Actions 会发布：

```text
ghcr.io/le-shi/gitea-runner:3.0-offline
```

## 包含内容

- Gitea Runner 3.0 上游镜像。
- Git、Git LFS、curl、jq、OpenSSH Client、rsync、tar、zip、unzip、xz 等常用工具。
- `actions.lock` 中固定 Commit SHA 的常用 Action 源码。
- AMD64 和 ARM64 多架构构建。
- GitHub Actions 构建缓存、SBOM 和 Provenance。

预置 Action 包括 checkout、cache、artifact、主要 `setup-*` 和 Docker Buildx/Push 系列。完整版本见 `actions.lock`。

## 重要边界

`/root/.cache/act` 是预热缓存，不是完整的 Action Mirror。Runner/Act 对缓存目录和浮动标签的处理可能随版本变化，因此：

1. 生产工作流应固定 Action Commit SHA。
2. 首次部署必须做真实断网测试。
3. 核心 Action 最稳妥的来源仍是内部 Gitea Mirror。
4. `setup-*` 下载的语言运行时不在 Action 缓存中，需要 Tool Cache 或语言基础镜像。
5. Docker Action 使用的镜像层不在 Action 缓存中，需要 Harbor 和镜像预拉取。
6. 云 API、GitHub API、SaaS 和在线漏洞库无法通过该镜像变成离线服务。

此外，GitHub `upload-artifact@v4`、`download-artifact@v4`、`cache@v4` 与特定 Gitea 版本的协议兼容性必须通过测试确认。必要时应在内部 Gitea 使用其兼容版本，而不是直接采用 GitHub 最新版本。

## 构建

```bash
docker build \
  --build-arg RUNNER_IMAGE=gitea/runner:3.0 \
  -t gitea-runner:3.0-offline .
```

验证镜像：

```bash
docker run --rm \
  --entrypoint /usr/local/bin/verify-offline-image \
  gitea-runner:3.0-offline
```

## 使用

沿用官方 Runner 镜像的启动参数、配置目录和注册方式，只替换镜像：

```yaml
services:
  runner:
    image: ghcr.io/le-shi/gitea-runner:3.0-offline
    restart: unless-stopped
    volumes:
      - ./runner-data:/data
      - ./act-cache:/root/.cache/act
      - ./tool-cache:/opt/hostedtoolcache
      - /var/run/docker.sock:/var/run/docker.sock
```

挂载空的 `./act-cache` 会遮蔽镜像内预置的 `/root/.cache/act`。首次启动前应将镜像缓存复制到持久化目录，或者暂时不挂载该目录：

```bash
docker create --name runner-cache-seed ghcr.io/le-shi/gitea-runner:3.0-offline
docker cp runner-cache-seed:/root/.cache/act ./act-cache
docker rm runner-cache-seed
```

## 更新 Action

`actions.lock` 同时记录缓存名称、仓库、Commit SHA 和人工审核的 Tag。每月工作流只负责解析新 SHA 并创建 Pull Request，不会自动合并：

```powershell
./scripts/update-actions.ps1
```

合并前必须检查上游 Release Notes、许可证、Node Runtime、外部下载地址、Gitea 兼容性以及 AMD64/ARM64 二进制支持。

## 发布流程

- Pull Request：检查锁文件，构建并测试 AMD64 镜像，不推送。
- `main`：测试通过后发布 AMD64/ARM64 镜像到 GHCR。
- Git Tag：额外发布对应版本标签。
- 每月：创建 Action SHA 更新 Pull Request。

如果 `gitea/runner:3.0` 不提供 ARM64 manifest，多架构发布会在 GitHub Actions 中明确失败。此时不能通过 QEMU 把 AMD64 基础镜像伪装成 ARM64，应改用已验证的 ARM64 上游镜像或基于官方 ARM64 二进制构建。
