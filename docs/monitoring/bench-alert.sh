#!/bin/bash
wrk -t2 -c100 -d90s http://47.116.100.83/api/v1/captcha >/tmp/wrk.log 2>&1 &
WRK_PID=$!
export KUBECONFIG=/home/AmazingYe/.kube/config-k3s-cloud
kubectl port-forward -n monitoring pod/alertmanager-monitoring-kube-prometheus-alertmanager-0 19093:9093 >/tmp/pf2.log 2>&1 &
PF_PID=$!
sleep 5
for i in 1 2 3 4 5 6 7; do
  echo "--- check $i ---"
  curl -s http://127.0.0.1:19093/api/v2/alerts | python3 -c "
import sys, json
d = json.load(sys.stdin)
names = [a['labels'].get('alertname','') for a in d]
demo = [a for a in d if a['labels'].get('alertname') == 'DemoHighCPU']
if demo:
    for a in demo:
        print('  DemoHighCPU state:', a['status'].get('state'), '| receivers:', a.get('receivers'))
else:
    print('  DemoHighCPU 未出现, 现有:', names[:10])
"
  sleep 12
done
wait $WRK_PID
kill $PF_PID 2>/dev/null
echo "=== WRK ==="
grep -E 'Requests/sec|requests in' /tmp/wrk.log
