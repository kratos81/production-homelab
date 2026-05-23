#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/rke2-cluster-02.yaml}"

echo "==> Installing MetalLB on cluster-02..."
helm repo add metallb https://metallb.github.io/metallb
helm repo update

helm upgrade --install metallb metallb/metallb \
  --namespace metallb-system \
  --create-namespace \
  --values "$SCRIPT_DIR/../values/metallb-values.yaml" \
  --wait --timeout 120s

echo "==> Waiting for MetalLB pods..."
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=metallb \
  --timeout=120s

echo "==> Applying IPAddressPool and L2Advertisement..."
kubectl apply -f "$SCRIPT_DIR/../values/metallb-ippool.yaml"

echo "==> MetalLB installed. LoadBalancer range: 192.168.1.200-220"
