#!/bin/bash
export KUBECONFIG=/home/AmazingYe/.kube/config-k3s-cloud
kubectl port-forward -n monitoring pod/prometheus-monitoring-kube-prometheus-prometheus-0 19090:9090 >/tmp/pf.log 2>&1 &
PF_PID=$!
sleep 4
for i in 1 2 3 4 5 6; do
  echo "--- check $i ---"
  curl -s 'http://127.0.0.1:19090/api/v1/query' --data-urlencode 'query=sum(rate(container_cpu_usage_seconds_total{namespace="go-admin-dev"}[1m])) by (pod)' | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d['data']['result']:
    print('  ', r['metric'].get('pod'), '=', r['value'][1])
if not d['data']['result']:
    print('   (无数据)')
"
  sleep 10
done
kill $PF_PID 2>/dev/null
