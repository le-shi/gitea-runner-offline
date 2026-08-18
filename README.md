# gitea-runner-offline

面向无公网或网络不稳定环境的 Gitea Runner 3.0 增强镜像。最终运行层为
`debian:bookworm-slim`；`gitea/runner:3.0` 只用于提取官方 Runner 二进制和
启动脚本，不以 Alpine 作为最终基础镜像。

发布地址：

```text
ghcr.io/le-shi/gitea-runner:3.0-offline
```

镜像同时发布 `linux/amd64` 和 `linux/arm64`，GitHub Workflow 会在两种原生
Runner 上构建，并用 `docker run --network none` 做断网验证。

镜像同时缓存 GitHub 上游 Actions 与公司 Gitea 的
`https://ailab-git.zbxsoft.com/mirror` 全部 7 个仓库。内部镜像使用的
checkout/cache/setup-node、Docker Actions，以及本地 CI 技能仍引用的
upload/download-artifact v3 均以固定 Commit SHA 落盘。每项同时保存可检查的
工作树和 act 离线模式可直接打开的 bare Git 仓库。
GitHub Hosted Runner 无法解析公司内网域名，因此构建阶段从字节一致的 GitHub
上游 Commit 获取源码，再按内部 `mirror/<repo>` 对应的缓存键写入成品镜像。

## 预装工具链

| 类别 | 版本 |
| --- | --- |
| Node.js | 18.20.8、20.20.2、22.23.2、24.19.0 |
| Python | 3.10.21、3.11.16、3.12.14、3.13.15、3.14.7 |
| Temurin JDK | 8.0.502+7、11.0.32+9、17.0.20+8、21.0.12+8.0.LTS、25.0.4+7.0.LTS |
| Go | 1.22.12、1.23.12、1.24.13、1.25.13 |
| .NET SDK | 6、8、9、10 |
| Rust | 1.97.1 |
| Ruby | 3.2.11、3.3.12、3.4.10 |
| 构建工具 | Maven 3.9.16、Gradle 8.14.5、Bun 1.3.14、Deno 2.9.5、uv 0.12.5 |
| DevOps CLI | Terraform 1.15.8、kubectl 1.34.10、Helm 3.21.4、Kustomize 5.8.1、Cosign 2.6.5、Syft 1.51.0、Trivy 0.74.0 |
| 通用工具 | Git、Git LFS、Docker CLI 27.5.1/28.5.2/29.7.2、Buildx 0.36、Compose 5.5、SSH、rsync、curl、jq、tar、zip、xz |

Node、Python、Go 和 Java 同时写入 `/opt/hostedtoolcache`，供官方
`actions/setup-*` 按 GitHub Runner tool-cache 规则查找。Workflow 会在断网状态
下实际执行 15 个 setup Action 主版本的 66 次运行时选择，而不只是检查目录是否存在。

为兼容更多按 GitHub Hosted Runner 环境编写的 Action，镜像还提供
`/opt/acttoolcache` 中的 Node 20/24 Action runtime、可写的 `/github/home`、
`/github/workflow`、`/github/file_commands` 和 `/opt/runner-temp`，并预装
`sudo`、`wget`、`gawk`、`zstd`、`gnupg`、`pipx`、`yq` 等常见命令。

镜像能力清单保存在 `/opt/gitea-runner-offline/capabilities.json`，可直接查看：

```bash
docker run --rm --entrypoint show-offline-capabilities \
  ghcr.io/le-shi/gitea-runner:3.0-offline
```

.NET SDK 分别保存在 `/opt/dotnet/6`、`/opt/dotnet/8`、`/opt/dotnet/9` 和
`/opt/dotnet/10`，同时合并到 `/usr/share/dotnet`。`dotnet6`、`dotnet8`、
`dotnet9`、`dotnet10` 可用于明确选择主版本。

## Action 源码缓存

`actions.lock` 当前固定 59 个 Action 版本与内部 mirror 兼容条目的不可变 Commit SHA，主要包括：

- checkout、cache、artifact、github-script；
- setup-node、setup-python、setup-java、setup-go、setup-dotnet；
- pnpm、uv、Gradle、Rust toolchain/cache；
- Docker login、Buildx、build-push、metadata、QEMU、Bake；
- Terraform、kubectl、Helm、Cosign、Trivy 和 SBOM。

源码位于 `/root/.cache/act`。生产 Workflow 也应使用 Commit SHA，避免浮动 Tag
在离线镜像构建后发生变化。

Docker CLI 同时安装在 `/opt/docker/27.5.1`、`/opt/docker/28.5.2` 和
`/opt/docker/29.7.2`，默认 `docker` 指向 29.7.2。可以使用 `docker27`、
`docker28`、`docker29` 直接选择，也可以执行 `use-docker-version 27|28|29`
切换默认命令。三个版本的 AMD64/ARM64 官方静态包都在 `docker-cli.lock`
中固定 SHA-256。

## 离线能力边界

| 类型 | 离线状态 | 说明 |
| --- | --- | --- |
| Shell/JavaScript Action | 可离线 | 前提是源码已在 `actions.lock` 中且 Runner 命中本地缓存 |
| setup-node/python/go/java | 可离线 | 必须选择镜像中已有版本，并设置 `check-latest: false` |
| setup-dotnet | 可离线使用固定版本 | 必须填写镜像中已安装的完整 SDK 版本；主版本、通配符或 `check-latest` 会触发版本元数据访问 |
| Docker Action | 有条件 | Action 源码可缓存，但其 `uses: docker://...` 或 Dockerfile 基础镜像也必须预拉取或放入内网 Registry |
| SCP/rsync/SSH | 可离线到内网 | 镜像已预装 CLI，不需要额外第三方 Action；目标主机仍须网络可达 |
| cache/artifact | 依赖服务端 | 依赖 Gitea 对应协议和服务，不是仅靠 Runner 镜像即可完全离线 |
| 云登录、发布、通知 | 不可纯离线 | AWS、Azure、GCP、GitHub API、SaaS 和公网制品库仍需访问对应服务 |

离线环境不要请求镜像未包含的新语言版本，也不要启用 `check-latest`。依赖本身
仍要由镜像内的 npm、pip、Maven、Go 和 Cargo 缓存命中，或由内网制品库提供。

缓存的 `setup-dotnet` 保留上游 `install-dotnet.sh.upstream`，并使用离线包装器
替代执行入口。包装器只复用 `/usr/share/dotnet` 中确切存在的 SDK；请求浮动版本
或缺失版本会立即报错，不会回退到公网下载。补丁记录位于
`/opt/gitea-runner-offline/offline-action-patches.txt`。

## 依赖缓存

镜像预热以下目录：

```text
/opt/offline-cache/npm
/opt/offline-cache/pip-wheelhouse
/opt/offline-cache/maven
/opt/offline-cache/go
/opt/offline-cache/cargo
/opt/offline-cache/ruby
/opt/offline-cache/mise
```

种子清单位于 `dependency-seeds/`。新增项目依赖时，应更新对应清单并重新构建，
然后以 `--network none` 验证真实安装或测试命令。

## 使用

可直接复制的部署与多语言 Workflow 示例位于：

- `examples/docker-compose.yaml`
- `examples/runner.env.example`
- `examples/workflows/multi-language-offline.yml`

快速启动：

```bash
cd examples
cp runner.env.example .env
# 编辑 .env 后启动；首次启动会先导入内置 Docker 镜像归档。
docker compose up -d
```

将 Workflow 复制到业务仓库：

```bash
mkdir -p .gitea/workflows
cp examples/workflows/multi-language-offline.yml \
  .gitea/workflows/offline-ci.yml
```

示例中的依赖安装只会命中镜像已经预热的缓存。业务项目自己的 npm、PyPI、
NuGet、Maven、Go、Cargo 或 Gem 依赖仍需提前加入镜像，或由内网制品库提供。

```yaml
services:
  runner:
    image: ghcr.io/le-shi/gitea-runner:3.0-offline
    restart: unless-stopped
    volumes:
      - ./runner-data:/data
      - /var/run/docker.sock:/var/run/docker.sock
```

不要直接把空目录挂载到 `/root/.cache/act`、`/opt/hostedtoolcache` 或
`/opt/offline-cache`，否则会遮蔽镜像内预置内容。如果必须持久化，应先从镜像
复制种子数据，再进行挂载。

## 构建和验证

构建期允许联网下载并固化所有工具、Action 和依赖；成品验证阶段关闭网络：

```bash
docker build --secret id=GITHUB_TOKEN,env=GITHUB_TOKEN \
  --build-arg RUNNER_IMAGE=gitea/runner:3.0 \
  -t gitea-runner:3.0-offline .

docker run --rm --network none \
  --entrypoint /usr/local/bin/verify-offline-image \
  gitea-runner:3.0-offline

docker run --rm --network none \
  --entrypoint /usr/local/bin/verify-offline-setup-actions \
  gitea-runner:3.0-offline
```

GitHub Workflow 还会生成 AMD64、ARM64 两份压缩 SPDX JSON SBOM Artifact，并在
两个架构都通过后发布多架构 manifest。

## 内置 Docker 镜像

镜像在 `/opt/offline-images` 中携带当前架构的 BuildKit、binfmt/QEMU、PostgreSQL、
Redis 和 MySQL Docker archive。挂载宿主机 Docker socket 后执行一次导入：

```bash
docker run --rm --network none \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --entrypoint load-offline-images \
  ghcr.io/le-shi/gitea-runner:3.0-offline
```

导入脚本会先校验 `SHA256SUMS`。构建阶段解析出的各架构 Registry digest 记录在
`/opt/offline-images/images.resolved.txt`，便于审计实际固化的镜像版本。
