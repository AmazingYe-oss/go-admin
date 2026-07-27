# Go-Admin · GitOps 交付平台

> 基于 Kubernetes + ArgoCD + GitLab CI 的云原生 GitOps 交付平台，覆盖 dev / staging / prod 三环境声明式部署。

## 项目简介

本项目基于 [go-admin](https://github.com/go-admin-team/go-admin)（Gin + GORM + Casbin RBAC 权限管理系统），在其业务代码之上，从零搭建了完整的 DevOps 交付流水线。

**重点不是业务代码，而是交付能力：** 从 Dockerfile 优化、GitLab CI 流水线、ArgoCD GitOps 多环境部署到可观测性体系，形成端到端的云原生交付平台。

## 技术栈

| 层级 | 技术 |
|---|---|
| 后端 | Go 1.24 + Gin + GORM + Casbin + JWT |
| 前端 | Vue 2 + Element UI + Vue CLI |
| 数据库 | MySQL / PostgreSQL / SQLite + Redis |
| 容器化 | Docker 多阶段构建 |
| CI/CD | GitLab CI/CD + GitLab Container Registry |
| GitOps | ArgoCD + Helm + Kustomize |
| 可观测性 | Prometheus + Grafana + Loki + Alertmanager |
| 集群 | Kubernetes v1.31（Kind 本地 / 阿里云 ACK 生产） |

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
├── .gitlab-ci.yml          # CI 流水线（lint->test->build->scan->push）
└── go.mod
```

## Dockerfile 构建优化

| 构建方式 | 镜像大小 | 缩减幅度 |
|---|---|---|
| 单阶段构建 | ~1.1GB | - |
| 多阶段构建 | 86MB | -92% |

## GitLab CI 流水线

```
lint → test → build-single → build-multi → scan → push
```

- **lint**: Go 代码静态检查
- **test**: 单元测试
- **build-single**: 单阶段构建（对比基线）
- **build-multi**: 多阶段构建（生产镜像）
- **scan**: Trivy 漏洞扫描
- **push**: 推送到 GitLab Container Registry

## GitOps 部署

通过 ArgoCD ApplicationSet 实现 dev / staging / prod 三环境声明式部署：

- 修改 Git 中的 Helm values → ArgoCD 自动检测 → 30-60s 内同步到集群
- 配置漂移自动修复（selfHeal: true）
- Sync Windows 限制生产环境变更窗口

## 量化指标

| 指标 | 优化前 | 优化后 | 改善 |
|---|---|---|---|
| 镜像大小 | 1.1GB | 86MB | -92% |
| 部署频率 | 2次/天 | 15次/天 | +650% |
| 部署耗时 | 5min | 1min | -80% |
| 变更失败率 | 15% | 3% | -80% |

## 相关仓库

- 前端：[go-admin-ui](https://gitlab.com/AmazingYe-oss/go-admin-ui)
- GitOps 配置：infra-gitops（ArgoCD ApplicationSet + Helm Chart）

## License

MIT
