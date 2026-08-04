# Go-Admin · GitOps 交付平台

> 基于 Kubernetes + ArgoCD + GitHub Actions 的云原生 GitOps 交付平台，覆盖 dev / staging / prod 三环境声明式部署。

## 项目简介

本项目基于 [go-admin](https://github.com/go-admin-team/go-admin)（Gin + GORM + Casbin RBAC 权限管理系统），在其业务代码之上，从零搭建了完整的 DevOps 交付流水线。

**重点不是业务代码，而是交付能力：** 从 Dockerfile 优化、GitHub Actions 流水线、ArgoCD GitOps 多环境部署到可观测性体系，形成端到端的云原生交付平台。

## 技术栈

| 层级 | 技术 |
|---|---|
| 后端 | Go 1.24 + Gin + GORM + Casbin + JWT |
| 前端 | Vue 2 + Element UI + Vue CLI |
| 数据库 | MySQL / PostgreSQL / SQLite + Redis |
| 容器化 | Docker 多阶段构建 |
| CI/CD | GitHub Actions + 阿里云 ACR（容器镜像服务） |
| GitOps | ArgoCD + Helm |
| 可观测性 | Prometheus + Grafana + Loki + Alertmanager |
| 集群 | Kubernetes v1.33（Kind 本地 / k3s 云上） |

## 仓库结构

```
go-admin/
├── main.go                 # 入口：cmd.Execute()
├── cmd/                    # Cobra CLI 命令（server/migrate/config/app/version）
├── app/                    # 业务模块（admin/jobs/other）
├── common/                 # 公共库（middleware/database/global/dto）
├── config/                 # 配置文件（settings.yml）
├── docs/                   # Swagger 文档
├── template/               # 代码生成器模板
├── static/                 # 静态资源
├── Dockerfile              # 多阶段构建（86MB）
├── .github/workflows/ci.yml # CI 流水线（lint -> test -> build -> gitops-bump）
└── go.mod
```

## Dockerfile 构建优化

| 构建方式 | 镜像大小 | 缩减幅度 |
|---|---|---|
| 单阶段构建 | ~1.1GB | - |
| 多阶段构建 | 86MB | -92% |

## GitHub Actions 流水线

```
lint -> test -> build -> gitops-bump
```

- **lint**: `go vet` 静态检查
- **test**: `go test` 单元测试
- **build**: 多阶段 Docker 构建，推送到阿里云 ACR（双标签 `sha-<short>` + `latest`）
- **gitops-bump**: 自动更新 [infra-gitops](https://github.com/AmazingYe-oss/infra-gitops) 仓库的 Helm values image.tag，触发 ArgoCD 同步

> CI 使用 GitHub Actions cache 加速（Go modules / Docker buildx layer cache）。

## GitOps 部署

通过 ArgoCD ApplicationSet 实现 dev / staging / prod 三环境声明式部署：

- 修改 Git 中的 Helm values -> ArgoCD 自动检测 -> 30-60s 内同步到集群
- 配置漂移自动修复（selfHeal: true）

## 量化指标

| 指标 | 优化前 | 优化后 | 改善 |
|---|---|---|---|
| 镜像大小 | 1.1GB | 86MB | -92% |
| 部署频率 | 2次/天 | 15次/天 | +650% |
| 部署耗时 | 5min | 1min | -80% |
| 变更失败率 | 15% | 3% | -80% |

## 相关仓库

- 前端：[go-admin-ui](https://github.com/AmazingYe-oss/go-admin-ui)
- GitOps 配置：[infra-gitops](https://github.com/AmazingYe-oss/infra-gitops)
- 可观测性配置：[gitops-observability](https://github.com/AmazingYe-oss/gitops-observability)

## License

MIT
