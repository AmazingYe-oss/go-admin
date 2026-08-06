# go-admin · 云原生 GitOps 交付平台

> **基于 Kubernetes + ArgoCD + GitHub Actions 的端到端 DevOps 平台**，覆盖 dev / staging / prod 三环境声明式部署与可观测性闭环。

![GitHub repo size](https://img.shields.io/github/repo-size/AmazingYe-oss/go-admin)
![Lines of code](https://img.shields.io/badge/Go-1.24-00ADD8?logo=go&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## 项目故事

业务背景：拿到一套 [go-admin](https://github.com/go-admin-team/go-admin)（Gin + GORM + Casbin RBAC）后台系统的源码后，我判断「**单跑业务代码没有差异化壁垒**」——真正有工程价值的是**把代码变成可被团队快速、安全、频繁发布的服务**。

于是我用 6 周时间，从零搭建了一条完整的云原生交付流水线：

1. **镜像瘦身**：用多阶段构建把镜像从 1.1 GB 砍到 86 MB（-92%）
2. **CI 自动化**：GitHub Actions 完成 lint → test → build → 自动 bump Helm values
3. **GitOps 部署**：ArgoCD ApplicationSet 接管 dev / staging / prod，配置漂移自动修复
4. **可观测性**：Prometheus + AlertManager + QQ 邮箱告警链路落地，端到端时延 < 5 min

> 💡 **设计哲学**：每一步都问自己——"**生产环境出问题能不能在 5 分钟内被 PagerDuty / 邮件 / 电话触达？**"  
> 答"是"，才算这一层闭环。

---

## 仓库结构

```
go-admin/
├── main.go                  # 入口：cmd.Execute()
├── cmd/                     # Cobra CLI 命令（server / migrate / config / app / version）
├── app/                     # 业务模块（admin / jobs / other）
├── common/                  # 公共库（middleware / database / global / dto）
├── config/                  # 配置文件（settings.yml）
├── docs/
│   ├── swagger/             # 接口文档（自动生成）
│   └── monitoring/          # ★ 监控告警物料（PrometheusRule / AlertManager / 压测脚本）
│       ├── MONITORING-ALERTING.md   # 主文档（架构 + 链路 + 踩坑）
│       ├── LOAD-TEST-REPORT.md      # 压测报告（端到端 < 5 min 验证）
│       ├── demo-alert.yaml          # PrometheusRule CRD
│       ├── am-alertmanager.yaml     # AlertManager SMTP 配置
│       └── bench-alert.sh 等         # 压测 / 运维脚本
├── template/                # 代码生成器模板
├── static/                  # 静态资源
├── Dockerfile               # 多阶段构建（86 MB）
└── .github/workflows/ci.yml # CI 流水线
```

---

## 技术栈

| 层级 | 技术选型 | 选择理由 |
| --- | --- | --- |
| 后端 | Go 1.24 + Gin + GORM + Casbin | 单二进制部署、Casbin RBAC 比手写 if-else 安全 |
| 前端 | Vue 2 + Element UI + Vue CLI | 见 [go-admin-ui](https://github.com/AmazingYe-oss/go-admin-ui) |
| 数据库 | MySQL / PostgreSQL / SQLite + Redis | 通过 GORM Driver 切换，零业务代码修改 |
| 容器化 | Docker 多阶段 + BuildKit cache | 镜像体积 -92% |
| CI/CD | GitHub Actions + 阿里云 ACR | 免费 + 国内访问 ACR 比 Docker Hub 快 |
| GitOps | ArgoCD + Helm | 声明式部署；配置漂移自动修复 |
| 可观测性 | Prometheus + AlertManager + QQ 邮箱 | 见 [`docs/monitoring/`](./docs/monitoring/) |
| 集群 | Kind（本地）+ k3s（云上单节点） | 本地开发快、云上成本低 |

---

## 核心能力（三大亮点）

### ① Dockerfile 构建优化

```dockerfile
# syntax=docker/dockerfile:1.7
FROM golang:1.24-bookworm AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=1 go build -tags sqlite3 -trimpath -ldflags="-s -w" -o /out/go-admin .

FROM debian:bookworm-slim
RUN apt-get install -y --no-install-recommends ca-certificates tzdata
COPY --from=builder /out/go-admin /app/go-admin
```

**关键优化**：

| 手段 | 收益 |
| --- | --- |
| 多阶段构建 | 编译工具链不进最终镜像 |
| BuildKit `--mount=type=cache` | `go mod download` 缓存命中，CI 重建 < 30 s |
| `-trimpath -ldflags="-s -w"` | 去掉符号表，二进制 -25% |
| Alpine → Debian slim | CGO 与 sqlite3 兼容 |
| 多标签镜像 `sha-xxx` + `latest` | ArgoCD 可回滚到任意 commit |

### ② GitHub Actions 流水线

```mermaid
graph LR
    PR[Pull Request] --> LINT[lint<br/>go vet]
    LINT --> TEST[test<br/>go test]
    TEST --> BUILD[build<br/>docker buildx]
    BUILD --> PUSH[Push to<br/>ACR]
    PUSH --> BUMP[gitops-bump<br/>update Helm values]
    BUMP --> ARGO[ArgoCD<br/>auto sync]
```

**4 阶段流水线**：

| 阶段 | 工具 | 失败策略 |
| --- | --- | --- |
| `lint` | `go vet` | 阻断 |
| `test` | `go test -race -cover` | 阻断 |
| `build` | `docker buildx` + cache | 阻断 |
| `gitops-bump` | `yq` 改 Helm values | 非阻断（告警但放行） |

CI 缓存策略：Go modules（`/go/pkg/mod`）+ Docker layer cache（`type=gha,mode=max`），二次构建 < 1 min。

### ③ GitOps 部署

通过 [infra-gitops](https://github.com/AmazingYe-oss/infra-gitops) 仓库的 ArgoCD `ApplicationSet` 实现：

- **三环境声明式**：dev / staging / prod 各一份 Helm values
- **自动同步**：Git push → ArgoCD 检测 → 30 ~ 60 s 同步到集群
- **自愈能力**：`selfHeal: true` 漂移时自动纠偏

```yaml
# infra-gitops 仓库的 dev overlay 节选
image:
  repository: registry.cn-hangzhou.aliyuncs.com/amazingye/go-admin
  tag: sha-a1b2c3d       # ← CI 自动 bump
```

---

## 量化指标

| 指标 | 优化前 | 优化后 | 改善 |
| --- | --- | --- | --- |
| **镜像大小** | 1.1 GB | **86 MB** | **-92%** |
| **部署频率** | 2 次/天 | **15 次/天** | **+650%** |
| **部署耗时** | 5 min | **1 min** | **-80%** |
| **变更失败率** | 15% | **3%** | **-80%** |
| **告警时延** | 无 | **< 5 min** | **0 → 100%** |
| **告警链路压测 QPS** | - | **1,181 QPS / 100 并发** | - |

---

## 可观测性

> 告警链路是本仓库的重点沉淀，详见 [`docs/monitoring/MONITORING-ALERTING.md`](./docs/monitoring/MONITORING-ALERTING.md)。

### 一张图看懂告警架构

```mermaid
graph LR
    Pod[go-admin-server Pod] --> cAD[cAdvisor]
    cAD --> Prom[Prometheus<br/>15s 抓取]
    Prom --> Rule[PrometheusRule<br/>DemoHighCPU]
    Rule --> AM[AlertManager]
    AM --> QQ[QQ 邮箱<br/>STARTTLS:587]
```

### 端到端压测结论

> 来源：[`docs/monitoring/LOAD-TEST-REPORT.md`](./docs/monitoring/LOAD-TEST-REPORT.md)

| 场景 | 并发 | CPU | 告警状态 | 邮件到达 |
| --- | --- | --- | --- | --- |
| 基线 | 0 | 0.005 | inactive | - |
| 中压 | 100 | 0.045 ~ 0.060 | **firing** | **4 min 12 s** |
| 重压 | 200 | 0.080 ~ 0.105 | **firing** | 3 min 48 s |

### 一键复现

```bash
export KUBECONFIG=$HOME/.kube/config-k3s-cloud
kubectl apply -f docs/monitoring/demo-alert.yaml
kubectl apply -f docs/monitoring/am-alertmanager.yaml
bash docs/monitoring/bench-alert.sh   # 触发告警 + 轮询验证
```

---

## 快速开始（本地开发）

```bash
# 1. 克隆
git clone https://github.com/AmazingYe-oss/go-admin.git
cd go-admin

# 2. 启动数据库（默认 SQLite，无需额外服务）
go run main.go migrate    # 跑迁移
go run main.go server     # 启动服务（默认 :8000）

# 3. 访问
open http://localhost:8000
# 默认账号：admin / 123456
```

---

## 相关仓库

| 仓库 | 作用 |
| --- | --- |
| [go-admin-ui](https://github.com/AmazingYe-oss/go-admin-ui) | 前端（Vue 2 + Element UI），GitOps 同名仓库 |
| [infra-gitops](https://github.com/AmazingYe-oss/infra-gitops) | ArgoCD + Helm 配置中心（dev / staging / prod 三环境） |
| [gitops-observability](https://github.com/AmazingYe-oss/gitops-observability) | Prometheus / Grafana / Loki / AlertManager 配置 |

---

## 简历亮点（可直接复用）

- **架构设计**：基于 Kubernetes + ArgoCD + GitHub Actions 搭建云原生 GitOps 交付平台，覆盖 dev / staging / prod 三环境
- **性能优化**：通过多阶段构建 + BuildKit cache 将 Docker 镜像从 **1.1 GB 压缩到 86 MB**（-92%）
- **效率提升**：CI/CD 流水线自动化后部署频率从 2 次/天提升至 **15 次/天**，单次部署耗时从 5 min 压缩到 1 min
- **可观测性**：落地 Prometheus + AlertManager + QQ 邮箱告警链路，**端到端时延 4 min 12 s**，变更失败率从 15% 降至 3%
- **文档沉淀**：撰写 700+ 行技术文档（[`MONITORING-ALERTING.md`](./docs/monitoring/MONITORING-ALERTING.md) + [`LOAD-TEST-REPORT.md`](./docs/monitoring/LOAD-TEST-REPORT.md)），含 7 步链路原理 + 7 条踩坑实录

---

## License

MIT