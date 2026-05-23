# GitOps with ArgoCD -- Hands-On Tutorial

## Overview

This tutorial teaches GitOps principles using ArgoCD as deployed on this platform. You will learn the App-of-Apps pattern, sync waves, multi-source applications, drift detection, and self-healing -- all with hands-on exercises against the live cluster.

**Prerequisites**: `kubectl` access to the cluster, ArgoCD CLI installed, Git access to the infra repo.

**Platform Tools Used**: ArgoCD, Helm, Git

---

## 1. GitOps Principles

GitOps is an operational framework where:

1. **Declarative** -- The entire system is described declaratively (YAML manifests, Helm charts)
2. **Versioned** -- The desired state is stored in Git (the single source of truth)
3. **Automated** -- Approved changes are automatically applied to the cluster
4. **Continuously Reconciled** -- Software agents (ArgoCD) ensure the cluster matches Git

### Why GitOps?

- **Auditability** -- Every change is a Git commit with author, timestamp, and diff
- **Rollback** -- `git revert` undoes any change
- **Consistency** -- No manual `kubectl apply` or `helm install` drift
- **Security** -- Developers push to Git; only ArgoCD touches the cluster

---

## 2. ArgoCD Architecture

```
┌──────────────────────────────────────────────┐
│                  ArgoCD                        │
│                                                │
│  ┌──────────────┐  ┌──────────────┐           │
│  │ API Server    │  │ Redis        │           │
│  │ (UI + CLI)    │  │ (caching)    │           │
│  └──────┬───────┘  └──────────────┘           │
│         │                                      │
│  ┌──────▼───────┐  ┌──────────────┐           │
│  │ App Controller│  │ Repo Server  │           │
│  │ (reconciler)  │  │ (git clone,  │           │
│  │               │  │  helm render)│           │
│  └──────────────┘  └──────────────┘           │
└──────────────────────────────────────────────┘
```

| Component | Role |
|---|---|
| **API Server** | Serves the UI and CLI, manages Application CRDs |
| **Application Controller** | Watches Application resources, compares desired vs live state, triggers syncs |
| **Repo Server** | Clones Git repos, renders Helm charts, generates manifests |
| **Redis** | Caches repo and manifest data for performance |

### Accessing ArgoCD

```bash
# Web UI
open https://argocd.homelab.local
# Login: admin / CHANGE_ME_ARGOCD_ADMIN_PASSWORD
# Or use Keycloak SSO (click "Log in via Keycloak")

# CLI login
argocd login argocd.homelab.local --username admin --password CHANGE_ME_ARGOCD_ADMIN_PASSWORD --insecure

# List all applications
argocd app list
```

---

## 3. The App-of-Apps Pattern

This platform uses the **App-of-Apps** pattern: a single root Application points to a directory of Application manifests. ArgoCD recursively creates and manages all child applications.

```
application/
├── app-of-apps.yaml          <-- Root Application (applied manually once)
└── apps/
    ├── metallb.yaml           <-- Child Application (sync wave -3)
    ├── metallb-config.yaml    <-- Child Application (sync wave -2)
    ├── prometheus.yaml        <-- Child Application (sync wave -1)
    ├── ingress-nginx.yaml     <-- Child Application (sync wave 0)
    ├── cert-manager.yaml      <-- Child Application (sync wave 1)
    ├── ...                    <-- 30+ more applications
    └── mattermost.yaml        <-- Child Application (sync wave 15)
```

### How it works:

1. You `kubectl apply -f application/app-of-apps.yaml` once
2. ArgoCD sees the root app pointing to `application/apps/`
3. ArgoCD creates an Application resource for each YAML file in that directory
4. Each child Application deploys its own Helm chart or manifests
5. Adding a new app = adding a YAML file to `application/apps/` and pushing to Git

---

## 4. Sync Waves

Sync waves control deployment order. Lower numbers deploy first.

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "5"
```

### Platform Sync Wave Order

| Wave | Applications | Why this order |
|---|---|---|
| **-3** | MetalLB | Must be first -- provides LoadBalancer IPs |
| **-2** | MetalLB Config | IP pools need MetalLB CRDs |
| **-1** | Prometheus, Loki, Tempo, Alloy, Longhorn | Core infrastructure |
| **0** | ingress-nginx | Needs MetalLB IP |
| **1** | cert-manager | Needs ingress for ACME (or self-signed) |
| **2** | cert-manager Config | Needs cert-manager CRDs |
| **3** | Kyverno | Admission controller before app deployments |
| **4-11** | Platform apps | Keycloak, ArgoCD, Vault, Harbor, GitLab, etc. |
| **12-15** | AI/ML and tools | MinIO, Ollama, MLflow, Mattermost, etc. |
| **16** | Config CRs | K8sGPT CR, Argo Workflows secret (need operators first) |

---

## 5. Hands-On: Creating an ArgoCD Application

### Single-Source Application (raw manifests)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-config
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "16"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/yourorg/production-homelab.git
    targetRevision: main
    path: application/values/my-config   # Directory of YAML manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 30s
        factor: 2
        maxDuration: 5m
```

### Multi-Source Application (Helm chart + Git values)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "15"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  sources:
    - repoURL: https://charts.example.com       # Helm chart repo
      chart: my-chart
      targetRevision: 1.*                        # Semver constraint
      helm:
        releaseName: my-app
        valueFiles:
          - $values/application/values/my-app-values.yaml
    - repoURL: https://github.com/yourorg/production-homelab.git
      targetRevision: main
      ref: values                                # Referenced as $values above
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 30s
        factor: 2
        maxDuration: 5m
```

**Key concept**: The `$values` ref lets you store Helm values in your Git repo while pulling the chart from an external Helm repository.

---

## 6. Managing Helm Values Through GitOps

All Helm values files live in `application/values/`:

```bash
ls application/values/
# argocd-values.yaml
# harbor-values.yaml
# prometheus-values.yaml
# mattermost-values.yaml
# ... etc
```

### Workflow to change a setting:

```bash
# 1. Edit the values file locally
vi application/values/prometheus-values.yaml

# 2. Commit and push
git add application/values/prometheus-values.yaml
git commit -m "Increase Prometheus retention to 30d"
git push origin main

# 3. ArgoCD detects the change within ~3 minutes (default poll interval)
# 4. ArgoCD renders the Helm chart with updated values
# 5. ArgoCD applies the diff to the cluster

# Watch the sync happen
argocd app get prometheus --refresh
```

---

## 7. Sync Policies

### Automated Sync

```yaml
syncPolicy:
  automated:
    prune: true      # Delete resources removed from Git
    selfHeal: true   # Revert manual changes on the cluster
```

| Setting | Behavior |
|---|---|
| `prune: true` | If you remove a resource from Git, ArgoCD deletes it from the cluster |
| `prune: false` | Removed resources become orphaned (still running but unmanaged) |
| `selfHeal: true` | If someone `kubectl edit`s a resource, ArgoCD reverts it |
| `selfHeal: false` | Manual changes persist until next Git push |

### Manual Sync

For sensitive apps, you may want manual sync:

```yaml
syncPolicy: {}  # No automated block = manual sync required
```

```bash
# Trigger manual sync
argocd app sync my-app

# Sync with prune
argocd app sync my-app --prune
```

---

## 8. Rollbacks and History

```bash
# View application history
argocd app history prometheus

# Rollback to a previous revision
argocd app rollback prometheus <REVISION_NUMBER>

# View the diff between current and desired state
argocd app diff prometheus
```

**Important**: With `automated.selfHeal: true`, a rollback will be immediately overridden by the next sync cycle. To truly rollback, revert the Git commit:

```bash
git revert HEAD
git push origin main
# ArgoCD syncs the reverted state
```

---

## 9. ArgoCD CLI Reference

```bash
# Login
argocd login argocd.homelab.local --insecure

# List all apps with status
argocd app list

# Get detailed status of one app
argocd app get harbor

# Force refresh (re-read from Git)
argocd app get harbor --refresh

# Sync a specific app
argocd app sync harbor

# View sync diff before applying
argocd app diff harbor

# View app logs
argocd app logs harbor

# Delete an app (and its resources)
argocd app delete my-test-app --cascade

# View app events
argocd app resources harbor
```

---

## 10. Drift Detection and Self-Healing

### Demonstration

```bash
# Step 1: Check current state of ingress-nginx
kubectl get deploy -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.replicas}'
# Output: 1

# Step 2: Manually scale it (simulating drift)
kubectl scale deploy -n ingress-nginx ingress-nginx-controller --replicas=3

# Step 3: Watch ArgoCD detect and revert the drift
argocd app get ingress-nginx --refresh
# Status will show "OutOfSync" briefly, then sync back to 1 replica

# Step 4: Verify self-healing
kubectl get deploy -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.replicas}'
# Output: 1 (reverted by ArgoCD)
```

ArgoCD polls Git every 3 minutes by default. Self-healing reverts manual changes within one reconciliation cycle.

---

## 11. Exercises

### Exercise 1: Explore the App-of-Apps

**Task**: List all ArgoCD applications and identify their sync waves, health status, and source type.

```bash
# Solution
argocd app list -o wide

# Or with kubectl
kubectl get applications -n argocd -o custom-columns=\
NAME:.metadata.name,\
SYNC:.status.sync.status,\
HEALTH:.status.health.status,\
WAVE:.metadata.annotations.argocd\.argoproj\.io/sync-wave
```

### Exercise 2: Create a Test Application

**Task**: Create a new ArgoCD Application that deploys an nginx pod using a raw manifest.

```bash
# Step 1: Create the manifest directory
mkdir -p application/values/test-nginx

# Step 2: Create a simple deployment
cat > application/values/test-nginx/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-nginx
  namespace: test-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-nginx
  template:
    metadata:
      labels:
        app: test-nginx
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
EOF

# Step 3: Create the ArgoCD Application
cat > application/apps/test-nginx.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-nginx
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "16"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/yourorg/production-homelab.git
    targetRevision: main
    path: application/values/test-nginx
  destination:
    server: https://kubernetes.default.svc
    namespace: test-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Step 4: Commit and push
git add application/apps/test-nginx.yaml application/values/test-nginx/
git commit -m "Add test nginx application"
git push origin main

# Step 5: Watch it deploy
argocd app get test-nginx --refresh
```

### Exercise 3: Test Self-Healing

**Task**: Manually modify a running resource and observe ArgoCD self-heal.

```bash
# Modify a ConfigMap or deployment label manually
kubectl label deploy -n test-nginx test-nginx manual-change=true

# Watch ArgoCD revert it
watch argocd app get test-nginx
```

### Exercise 4: Simulate a Failed Sync

**Task**: Push an invalid manifest and observe ArgoCD's retry behavior.

```bash
# Create an invalid resource (missing required fields)
cat > application/values/test-nginx/bad-resource.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: test-service
spec:
  # Missing selector and ports -- this will fail
EOF

git add . && git commit -m "Add broken manifest" && git push

# Watch the sync fail and retry (limit: 5, backoff: 30s * 2^n)
argocd app get test-nginx

# Fix it
git revert HEAD && git push
```

### Exercise 5: Compare Multi-Source vs Single-Source

**Task**: Examine a multi-source application (e.g., Mattermost) and a single-source application (e.g., monitoring-extras). Identify the differences in their `spec.source` vs `spec.sources` fields.

```bash
# Multi-source (Helm + Git values)
kubectl get application mattermost -n argocd -o yaml | grep -A 20 'sources:'

# Single-source (raw manifests)
kubectl get application monitoring-extras -n argocd -o yaml | grep -A 10 'source:'
```

---

## 12. GitOps Anti-Patterns

| Anti-Pattern | Why It's Bad | Correct Approach |
|---|---|---|
| `kubectl apply` directly | Bypasses Git history, causes drift | Push to Git, let ArgoCD sync |
| Secrets in Git (plaintext) | Security risk | Use Vault, SealedSecrets, or ExternalSecrets |
| One mega-repo for all teams | Merge conflicts, slow CI | Repo-per-team or mono-repo with CODEOWNERS |
| Manual sync with `selfHeal: false` | Drift accumulates silently | Enable selfHeal for non-sensitive apps |
| Skipping sync waves | Race conditions (e.g., CRDs not ready) | Use sync waves for dependency ordering |
| Hardcoding image tags in values | No traceability | Use Git commit SHA or semantic versions |

### Best Practices

1. **Git is the source of truth** -- Never modify cluster state directly
2. **Use sync waves** -- Ensure CRDs exist before CRs, operators before configs
3. **Enable automated sync + prune + selfHeal** -- For full GitOps compliance
4. **Use multi-source applications** -- Keep Helm charts upstream, values in your repo
5. **Protect the main branch** -- Require PRs with reviews for production changes
6. **Use ApplicationSets** for multi-cluster -- Generate apps programmatically across clusters
7. **Monitor sync status** -- Set up alerts for Degraded or OutOfSync applications

---

## Next Steps

- [Monitoring & Alerting Tutorial](monitoring-and-alerting.md) -- Monitor ArgoCD sync metrics in Grafana
- [DevSecOps Tutorial](devsecops.md) -- Integrate GitOps with CI/CD security scanning
- [Security Tutorial](security.md) -- Use Kyverno policies to enforce GitOps standards
