# syntax=docker/dockerfile:1.7

# -------- builder --------
# 用 golang:1.24-bookworm（Debian），自带 gcc，无需额外装包
FROM golang:1.24-bookworm AS builder
WORKDIR /src

ENV GOPROXY=https://goproxy.cn,direct

# 依赖层缓存
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download

# 源码
COPY . .

# CGO 开启（SQLite 编译需要）；保留 sqlite3 build tag
ENV CGO_ENABLED=1 GOOS=linux GOARCH=amd64
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -tags sqlite3 -trimpath -ldflags="-s -w" -o /out/go-admin .

# -------- runtime --------
FROM debian:bookworm-slim
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m -u 1000 appuser

# 拷贝编译产物 + 配置 + 静态资源 + 模板
COPY --from=builder /out/go-admin /app/go-admin
COPY config/ ./config/
COPY static/ ./static/
COPY template/ ./template/

# 让 appuser 拥有 /app 全部文件（必须能写 temp/logs）
RUN chown -R appuser:appuser /app

USER appuser
EXPOSE 8000

ENTRYPOINT ["/app/go-admin"]
CMD ["server", "-c", "/app/config/settings.yml"]