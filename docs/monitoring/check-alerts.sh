#!/bin/bash
export KUBECONFIG=/home/AmazingYe/.kube/config-k3s-cloud
POD=prometheus-monitoring-kube-prometheus-prometheus-0

kubectl port-forward -n monitoring pod/$POD 19090:9090 >/tmp/pf.log 2>&1 &
PF_PID=$!
sleep 4

echo "=== ALERTS (DemoHighCPU) ==="
curl -s http://127.0.0.1:19090/api/v1/alerts | python3 -c "
import sys, json
d = json.load(sys.stdin)
found = False
for a in d['data']['alerts']:
    if a['labels'].get('alertname') == 'DemoHighCPU':
        found = True
        print('alertname:', a['labels'].get('alertname'), '| state:', a['state'], '| value:', a.get('value'))
if not found:
    print('(DemoHighCPU 不在当前告警列表)')
"

echo ""
echo "=== RULES EVAL (demo) ==="
curl -s http://127.0.0.1:19090/api/v1/rules | python3 -c "
import sys, json
d = json.load(sys.stdin)
for g in d['data']['groups']:
    if 'demo' in g['name'].lower():
        for r in g['rules']:
            print('rule:', r['name'], '| state:', r['state'], '| health:', r.get('health'), '| lastError:', str(r.get('lastError', ''))[:150])
        print('(demo 规则组找到)')
"

echo ""
echo "=== PROMETHEUS -> ALERTMANAGER ==="
curl -s http://127.0.0.1:19090/api/v1/status/config | python3 -c "
import sys, json
d = json.load(sys.stdin)
cfg = d['data']['yaml']
start = cfg.find('alerting:')
print(cfg[start:start+300] if start >= 0 else '(未找到 alerting 段)')
"

echo ""
echo "=== Demo 指标实时值 ==="
curl -s 'http://127.0.0.1:19090/api/v1/query' --data-urlencode 'query=sum(rate(container_cpu_usage_seconds_total{namespace="go-admin-dev"}[1m])) by (pod)' | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d['data']['result']:
    print(r['metric'].get('pod'), '=', r['value'][1])
if not d['data']['result']:
    print('(无数据)')
"

kill $PF_PID 2>/dev/null
