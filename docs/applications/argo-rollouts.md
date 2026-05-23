# Argo Rollouts - Progressive Delivery

## Overview

Argo Rollouts is a Kubernetes controller that provides advanced deployment strategies such as canary releases, blue-green deployments, and automated rollbacks driven by metric analysis. It extends the standard Kubernetes Deployment resource with a `Rollout` CRD that supports fine-grained traffic management, Prometheus-based analysis, and integration with ingress controllers for traffic splitting. On this platform, Argo Rollouts works alongside ArgoCD to provide a complete GitOps-driven progressive delivery pipeline.

## Architecture on This Platform

- **Deployment model**: Helm chart deployed via ArgoCD (sync-wave 6).
- **Namespace**: `argo-rollouts`
- **Components**:
  - **Rollouts Controller** (1 replica): Watches `Rollout` resources and manages the progressive delivery lifecycle.
  - **Dashboard** (1 replica): Web UI for visualizing and managing rollouts, accessible at `rollouts.homelab.local`.
- **Metrics**: Prometheus ServiceMonitor enabled with label `release: prometheus`.
- **Analysis Provider**: Prometheus at `prometheus-kube-prometheus-prometheus.monitoring:9090`.
- **Traffic Management**: Integrates with ingress-nginx for header-based and weight-based traffic splitting.

## Deployment Strategies

### Canary
Gradually shifts traffic from the stable version to the new version in configurable steps, running Prometheus analysis at each step.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-app
spec:
  strategy:
    canary:
      steps:
        - setWeight: 10
        - pause: {duration: 5m}
        - analysis:
            templates:
              - templateName: success-rate
        - setWeight: 50
        - pause: {duration: 5m}
        - analysis:
            templates:
              - templateName: success-rate
      canaryService: my-app-canary
      stableService: my-app-stable
      trafficRouting:
        nginx:
          stableIngress: my-app-ingress
```

### Blue-Green
Deploys the new version alongside the old, switches traffic atomically after verification.

```yaml
spec:
  strategy:
    blueGreen:
      activeService: my-app-active
      previewService: my-app-preview
      autoPromotionEnabled: true
      prePromotionAnalysis:
        templates:
          - templateName: smoke-test
```

### AnalysisTemplate Example
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
    - name: success-rate
      interval: 60s
      successCondition: result[0] >= 0.99
      provider:
        prometheus:
          address: http://prometheus-kube-prometheus-prometheus.monitoring:9090
          query: |
            sum(rate(http_requests_total{status=~"2.*",app="{{args.service-name}}"}[5m]))
            /
            sum(rate(http_requests_total{app="{{args.service-name}}"}[5m]))
```

## Best Practices

### Security
- Use `autoPromotionEnabled: false` in production to require manual approval before full promotion.
- Define `prePromotionAnalysis` for blue-green deployments to verify the new version before switching traffic.
- Restrict `Rollout` creation to CI/CD service accounts using RBAC.

### Performance
- Set analysis `interval` to at least 60s to allow metrics to stabilize between checks.
- Use `failureLimit` and `inconclusiveLimit` in AnalysisTemplates to prevent indefinite analysis runs.
- Keep the controller at 1 replica for clusters with fewer than 100 Rollouts.

### Reliability
- Always define a `maxSurge` and `maxUnavailable` to control resource consumption during rollouts.
- Use `abortScaleDownDelaySeconds` to keep old pods running briefly after abort for debugging.
- Monitor the Argo Rollouts controller metrics in Grafana for rollout success/failure rates.

## Configuration Reference

### Values (`argo-rollouts-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `controller.replicas` | `1` | Single controller replica |
| `controller.metrics.serviceMonitor.enabled` | `true` | Prometheus metrics |
| `dashboard.enabled` | `true` | Enable web dashboard |
| `dashboard.ingress.enabled` | `true` | Expose dashboard via ingress |
| `dashboard.ingress.hosts[0]` | `rollouts.homelab.local` | Dashboard URL |
| `dashboard.ingress.tls` | homelab-ca-issuer | TLS via cert-manager |

## Useful Commands

| Task | Command |
|---|---|
| List rollouts | `kubectl get rollouts -A` |
| Watch rollout status | `kubectl argo rollouts get rollout <name> -n <ns> --watch` |
| Promote canary | `kubectl argo rollouts promote <name> -n <ns>` |
| Abort rollout | `kubectl argo rollouts abort <name> -n <ns>` |
| Retry rollout | `kubectl argo rollouts retry rollout <name> -n <ns>` |
| Open dashboard | `https://rollouts.homelab.local` |
| Install kubectl plugin | `brew install argoproj/tap/kubectl-argo-rollouts` |

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Rollout stuck at a step | Analysis failing or inconclusive | Check AnalysisRun: `kubectl get analysisrun -n <ns>` |
| Traffic not splitting | Ingress not annotated correctly | Ensure `nginx.ingress.kubernetes.io/canary: "true"` on canary ingress |
| Dashboard inaccessible | Ingress or TLS issue | Check `kubectl get ingress -n argo-rollouts` and cert status |
| Controller OOMKilled | Too many concurrent rollouts | Increase controller memory limits |

## Related Components

- **ArgoCD** -- Triggers rollouts by syncing Rollout manifests from Git.
- **ingress-nginx** -- Handles traffic splitting between stable and canary versions.
- **Prometheus** -- Provides metrics for AnalysisTemplates (error rates, latency, custom metrics).
- **Grafana** -- Visualize rollout metrics and analysis results.
