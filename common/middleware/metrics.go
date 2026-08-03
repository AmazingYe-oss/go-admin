package middleware

import (
	"os"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// appName 用于给指标打上应用标签，默认 go-admin，可通过环境变量 APP_NAME 覆盖。
// 这样文档中的 PromQL（{app="go-admin"}）可直接使用，复制到其他项目也无需改代码。
func appName() string {
	if v := os.Getenv("APP_NAME"); v != "" {
		return v
	}
	return "go-admin"
}

var (
	// httpRequestsTotal 统计每个请求的总数（RED: Rate + Errors 的数据源）
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests processed.",
		},
		[]string{"app", "method", "status"},
	)

	// httpRequestDurationSeconds 统计请求耗时分布（RED: Duration 的数据源，P99 由此计算）
	httpRequestDurationSeconds = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request latency distributions in seconds.",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"app", "method"},
	)
)

func init() {
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDurationSeconds)
}

// Prometheus 返回一个 Gin 全局中间件：每个请求结束后记录一次指标。
// 用法：在 InitMiddleware 中 r.Use(Prometheus())
func Prometheus() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next() // 放行请求，执行后续 handler 与业务逻辑
		// 请求已结束：记录状态码（3 位数字字符串，便于 PromQL status=~"5.." 匹配）
		httpRequestsTotal.WithLabelValues(appName(), c.Request.Method, strconv.Itoa(c.Writer.Status())).Inc()
		httpRequestDurationSeconds.WithLabelValues(appName(), c.Request.Method).Observe(time.Since(start).Seconds())
	}
}

// MetricsHandler 返回 /metrics 端点处理器，暴露 Go 运行时指标 + 上面两个自定义指标。
// 用法：在路由注册处 r.GET("/metrics", middleware.MetricsHandler())
func MetricsHandler() gin.HandlerFunc {
	return gin.WrapH(promhttp.Handler())
}
