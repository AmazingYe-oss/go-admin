#!/bin/bash
export KUBECONFIG=/home/AmazingYe/.kube/config-k3s-cloud
kubectl port-forward -n monitoring pod/alertmanager-monitoring-kube-prometheus-alertmanager-0 19093:9093 >/tmp/pf2.log 2>&1 &
PF_PID=$!
sleep 4
echo "=== AlertManager 内当前 alerts ==="
curl -s http://127.0.0.1:19093/api/v2/alerts | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('total alerts:', len(d))
for a in d[:10]:
    print(' ', a['labels'].get('alertname'), '| state:', a['status'].get('state'), '| receivers:', a.get('receivers'))
"
kill $PF_PID 2>/dev/null
