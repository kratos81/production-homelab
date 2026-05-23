#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/rke2-cluster-02.yaml}"

echo "==> Installing ArgoCD on cluster-02..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values "$SCRIPT_DIR/../values/argocd-values.yaml" \
  --wait --timeout 180s

echo "==> Waiting for ArgoCD server..."
kubectl wait --namespace argocd \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --timeout=180s

echo "==> Configuring repo credentials..."
kubectl -n argocd create secret generic repo-infra \
  --from-literal=type=git \
  --from-literal=url=https://github.com/kratos81/infra.git \
  --from-literal=username=kenna \
  --from-literal=password=CHANGE_ME_GITHUB_PAT \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n argocd label secret repo-infra argocd.argoproj.io/secret-type=repository --overwrite

echo ""
echo "==> ArgoCD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""

echo ""
echo "==> Applying App of Apps..."
kubectl apply -f "$SCRIPT_DIR/../argocd/app-of-apps.yaml"

echo ""
echo "==> ArgoCD UI:"
kubectl -n argocd get svc argocd-server -o jsonpath='  http://{.status.loadBalancer.ingress[0].ip}'
echo ""
echo "==> Done. ArgoCD will now sync all applications."
