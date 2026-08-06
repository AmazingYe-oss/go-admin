#!/bin/bash
K="kubectl --kubeconfig=/home/AmazingYe/.kube/config-k3s-cloud"
echo "=== Finalizers ==="
$K get ns argocd -o jsonpath='{.metadata.finalizers}' 2>&1
echo ""
echo "=== Resources in ns ==="
$K get all -n argocd 2>&1
echo ""
echo "=== All resources in ns ==="
$K api-resources --verbs=list --namespaced -o name 2>/dev/null | while read r; do
  result=$($K get $r -n argocd --ignore-not-found 2>/dev/null)
  if [ -n "$result" ]; then echo "--- $r ---"; echo "$result"; fi
done
