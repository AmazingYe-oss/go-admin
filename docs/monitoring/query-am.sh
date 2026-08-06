#!/bin/bash
export KUBECONFIG=/home/AmazingYe/.kube/config-k3s-cloud
kubectl port-forward -n monitoring pod/prometheus-monitoring-kube-prometheus-prometheus-0 19090:9090 >/tmp/pf.log 2>&1 &
PF_PID=$!
sleep 4
echo "=== ALERTMANAGERS 连接状态 ==="
curl -s 'http://127.0.0.1:19090/api/v1/alertmanagers' | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('active:', d['data']['activeAlertmanagers'])
print('dropped:', d['data']['droppedAlertmanagers'])
"
echo ""
echo "=== alerting 配置段 ==="
curl -s 'http://127.0.0.1:19090/api/v1/status/config' | python3 -c "
import sys, json
d = json.load(sys.stdin)
cfg = d['data']['yaml']
start = cfg.find('alerting:')
print(cfg[start:start+600])
"
kill $PF_PID 2>/dev/null
