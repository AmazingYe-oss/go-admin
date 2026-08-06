#!/bin/bash
kubectl --kubeconfig=/home/AmazingYe/.kube/config-k3s-cloud patch ns argocd --type=merge -p '{"metadata":{"finalizers":null}}'
echo "---"
kubectl --kubeconfig=/home/AmazingYe/.kube/config-k3s-cloud get ns argocd 2>&1
