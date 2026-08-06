# go-admin

Backend service for the go-admin platform. Forked from [go-admin-team/go-admin](https://github.com/go-admin-team/go-admin) and adapted for multi-environment Kubernetes delivery via ArgoCD.

- Language: Go 1.24
- Web framework: Gin
- ORM: GORM (MySQL / PostgreSQL / SQLite)
- Auth: Casbin RBAC
- Default port: `:8000` (HTTP) / `:4194` (Go runtime metrics)

## Layout

```
cmd/                     Cobra entry points (server / migrate / config / app / version)
app/                     Business modules (admin / jobs / other)
common/                  Shared libraries (middleware / database / global / dto)
config/                  Runtime config (settings.yml)
docs/swagger/            Auto-generated Swagger docs
docs/monitoring/         PrometheusRule + AlertManager + load-test scripts
                         (see docs/monitoring/MONITORING-ALERTING.md)
template/                CRUD code-generator templates
static/                  Static assets
Dockerfile               Multi-stage build (see below)
.github/workflows/ci.yml CI pipeline (lint -> test -> build -> gitops-bump)
```

## Docker build

Multi-stage Dockerfile, BuildKit cache mounts for `go mod` and `go-build`:

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
    CGO_ENABLED=1 go build -tags sqlite3 -trimpath \
    -ldflags="-s -w" -o /out/go-admin .

FROM debian:bookworm-slim
RUN apt-get install -y --no-install-recommends ca-certificates tzdata
COPY --from=builder /out/go-admin /app/go-admin
```

Resulting image is ~86 MB. SQLite is built with `CGO_ENABLED=1`, so Alpine is not used (musl + glibc incompatibility was the reason). `-trimpath -ldflags="-s -w"` strips the symbol table.

## CI

`.github/workflows/ci.yml` runs four stages on every push to `main`:

| Stage         | Tool                                       | On failure |
|---------------|--------------------------------------------|------------|
| `lint`        | `go vet`                                   | block      |
| `test`        | `go test -race -cover`                     | block      |
| `build`       | `docker buildx`                            | block      |
| `gitops-bump` | `yq` patches Helm `image.tag` in `infra-gitops` | warn, do not block |

Caches: Go modules (`/go/pkg/mod`) + Docker layer cache (`type=gha,mode=max`). Cold build ~3 min, warm build ~30 s on GitHub-hosted runners.

Images are pushed to Aliyun ACR with two tags: immutable `sha-<short>` and floating `latest`. The `sha-` tag is what `infra-gitops` consumes.

## Deployment

This repo does not contain Helm charts. See [infra-gitops](https://github.com/AmazingYe-oss/infra-gitops) for the ArgoCD ApplicationSet that deploys the image to `go-admin-dev`, `go-admin-staging`, `go-admin-prod`.

Every CI run on `main` triggers `gitops-bump`, which commits `image.tag` updates into `infra-gitops/go-admin-chart/values-*.yaml`. ArgoCD then auto-syncs within ~30-60 s.

## Local development

```bash
git clone https://github.com/AmazingYe-oss/go-admin.git
cd go-admin

# SQLite (default, no extra services)
go run main.go migrate
go run main.go server          # listens on :8000

# MySQL
# edit config/settings.yml -> DriverName=mysql + DSN, then the same two commands
```

Default credentials: `admin / 123456`. Change them before exposing the service.

## Monitoring

Alerting rules and load-test scripts live under `docs/monitoring/`. See [`docs/monitoring/MONITORING-ALERTING.md`](./docs/monitoring/MONITORING-ALERTING.md) for the full chain (Pod -> cAdvisor -> Prometheus -> PrometheusRule -> AlertManager -> QQ SMTP).

To reproduce the end-to-end alert:

```bash
export KUBECONFIG=$HOME/.kube/config-k3s-cloud
kubectl apply -f docs/monitoring/demo-alert.yaml
kubectl apply -f docs/monitoring/am-alertmanager.yaml
bash docs/monitoring/bench-alert.sh
```

## Known limitations

- SQLite driver is wired in by default; `pgx` and `mongo` drivers are not yet integrated.
- No `/healthz` or `/readyz` endpoint. Readiness is purely TCP-based (see Helm chart `readinessProbe`).
- Metric output is from the Go runtime (`expvar`) and a basic `gin` middleware. Custom business metrics are not yet exposed.

## Related repos

| Repo | Role |
|------|------|
| [go-admin-ui](https://github.com/AmazingYe-oss/go-admin-ui) | Frontend SPA, deployed together with this service |
| [infra-gitops](https://github.com/AmazingYe-oss/infra-gitops) | ArgoCD + Helm config, source of truth for image tags |

## License

MIT