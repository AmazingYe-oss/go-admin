#!/bin/bash
wrk -t2 -c100 -d110s http://47.116.100.83/api/v1/captcha >/tmp/wrk.log 2>&1 &
WRK_PID=$!
export KUBECONFIG=/home/AmazingYe/.kube/config-k3s-cloud
kubectl port-forward -n monitoring pod/prometheus-monitoring-kube-prometheus-prometheus-0 19090:9090 >/tmp/pf.log 2>&1 &
PF_PID=$!
sleep 5
for i in 1 2 3 4 5 6 7 8; do
  echo "--- check $i ---"
  curl -s 'http://127.0.0.1:19090/api/v1/query' --data-urlencode 'query=sum(rate(container_cpu_usage_seconds_total{namespace="go-admin-dev"}[1m])) by (pod)' | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d['data']['result']:
    if 'go-admin-dev-go-admin' in r['metric'].get('pod',''):
        print('  CPU:', r['metric'].get('pod'), '=', r['value'][1])
"
  curl -s 'http://127.0.0.1:19090/api/v1/alerts' | python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d['data']['alerts']:
    if a['labels'].get('alertname') == 'DemoHighCPU':
        print('  ALERT state:', a['state'])
if not any(a['labels'].get('alertname') == 'DemoHighCPU' for a in d['data']['alerts']):
    print('  ALERT: 无 DemoHighCPU')
"
  sleep 13
done
wait $WRK_PID
kill $PF_PID 2>/dev/null
echo "=== WRK RESULT ==="
grep -E 'Requests/sec|Socket errors|requests in' /tmp/wrk.log
