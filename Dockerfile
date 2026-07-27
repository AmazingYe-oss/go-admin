
# ---------- 阶段 1: builder（编译阶段）----------
FROM golang:1.24 AS builder

# 设置工作目录
WORKDIR /go/src/app

# 配置国内 Go 模块代理
ENV GOPROXY=https://goproxy.cn,direct
ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

# 先复制依赖文件，利用 Docker 缓存（依赖不变时跳过 go mod download）
COPY go.mod go.sum ./
RUN go mod download

# 复制源码并编译（-ldflags="-s -w" 去掉调试信息，减小二进制体积）
COPY . .
RUN go build -ldflags="-s -w" -o go-admin .

# ---------- 阶段 2: runtime（运行阶段）----------
FROM alpine:3.19

# 安装最小运行时依赖（ca-certificates 用于 HTTPS，tzdata 用于时区）
RUN apk --no-cache add ca-certificates tzdata

# 设置时区
ENV TZ=Asia/Shanghai

# 创建非 root 用户运行（安全最佳实践）
RUN adduser -D -h /app appuser
WORKDIR /app

# 从 builder 阶段只复制编译好的二进制文件
COPY --from=builder /go/src/app/go-admin .

# 复制运行时需要的目录（config 配置、static 上传文件、template 代码模板）
COPY config/ ./config/
COPY static/ ./static/
COPY template/ ./template/

# 切换为非 root 用户
USER appuser

# 声明端口
EXPOSE 8000

# 启动命令：server 子命令启动 HTTP API 服务
CMD ["./go-admin", "server", "-c", "config/settings.yml"]