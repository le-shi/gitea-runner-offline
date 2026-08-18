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

## 预装工具链

| 类别 | 版本 |
| --- | --- |
| Node.js | 18、20、22、24 |
| Python | 3.10、3.11、3.12、3.13、3.14 |
| Temurin JDK | 8、11、17、21、25 |
| Go | 1.22、1.23、1.24、1.25 |
| .NET SDK | 6、8、9、10 |
| Rust | stable |
| 构建工具 | Maven 3.9、Gradle 8、Bun 1、Deno 2、uv |
| DevOps CLI | Terraform、kubectl、Helm、Kustomize、Cosign、Syft、Trivy |
| 通用工具 | Git、Git LFS、Docker CLI、Buildx 0.36、Compose 5.5、SSH、rsync、curl、jq、tar、zip、xz |

Node、Python、Go 和 Java 同时写入 `/opt/hostedtoolcache`，供官方
`actions/setup-*` 按 GitHub Runner tool-cache 规则查找。Workflow 会在断网状态
下实际执行所有 22 个已覆盖版本的 setup Action，而不只是检查目录是否存在。

.NET SDK 分别保存在 `/opt/dotnet/6`、`/opt/dotnet/8`、`/opt/dotnet/9` 和
`/opt/dotnet/10`，同时合并到 `/usr/share/dotnet`。`dotnet6`、`dotnet8`、
`dotnet9`、`dotnet10` 可用于明确选择主版本。

## Action 源码缓存

`actions.lock` 当前固定 27 个 Action 的不可变 Commit SHA，主要包括：

- checkout、cache、artifact、github-script；
- setup-node、setup-python、setup-java、setup-go、setup-dotnet；
- pnpm、uv、Gradle、Rust toolchain/cache；
- Docker login、Buildx、build-push、metadata、QEMU、Bake；
- Terraform、kubectl、Helm、Cosign、Trivy 和 SBOM。

源码位于 `/root/.cache/act`。生产 Workflow 也应使用 Commit SHA，避免浮动 Tag
在离线镜像构建后发生变化。

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
/opt/offline-cache/mise
```

种子清单位于 `dependency-seeds/`。新增项目依赖时，应更新对应清单并重新构建，
然后以 `--network none` 验证真实安装或测试命令。

## 使用

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
