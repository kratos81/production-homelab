# Kyverno - Policy Engine

## Overview

Kyverno is a Kubernetes-native policy engine that validates, mutates, and generates resources using policies written as Kubernetes resources (no new language to learn). On this platform, Kyverno enforces security and operational policies across all namespaces, acting as a validating and mutating admission webhook.

## Architecture on This Platform

- **Deployment model**: Helm chart deployed via ArgoCD.
- **Namespace**: `kyverno`
- **Components**:
  - **Admission Controller** (1 replica): Intercepts API server requests for policy enforcement.
  - **Background Controller**: Processes policies against existing resources and handles generate/mutate-existing rules.
  - **Cleanup Controller**: Handles cleanup policies and TTL-based resource removal.
  - **Reports Controller**: Generates and manages policy reports.
- **Metrics**: ServiceMonitor enabled on admission and background controllers, labeled `release: prometheus`.

## Best Practices

### Security
- Start with `Audit` mode policies before switching to `Enforce` to avoid blocking legitimate workloads.
- Apply baseline Pod Security Standards via Kyverno policies as a complement or replacement for PodSecurity admission.
- Use `ClusterPolicy` for cluster-wide rules and `Policy` for namespace-scoped rules.
- Protect the `kyverno` namespace with policies that prevent accidental deletion of Kyverno resources.

### Performance
- Keep the admission controller replica count at 1 for small clusters; increase for clusters with high API request rates.
- Resource limits are set per controller (admission: 500m/512Mi, background: 250m/256Mi, cleanup: 250m/256Mi, reports: 250m/256Mi). Monitor memory usage, especially on the admission controller when processing complex policies.
- Exclude system namespaces (kube-system, kyverno) from policies where appropriate to reduce webhook overhead.

### Reliability
- Monitor Kyverno webhook health -- if the admission controller is unavailable, it can block all resource creation (depending on `failurePolicy`).
- Set `failurePolicy: Ignore` on non-critical policies to prevent cluster lockout.
- Use `PolicyReport` and `ClusterPolicyReport` resources to audit policy violations.

## Configuration Reference

### Values (`kyverno-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `admissionController.replicas` | `1` | Single replica for admission |
| `admissionController.resources.requests.cpu` | `100m` | CPU request |
| `admissionController.resources.limits.memory` | `512Mi` | Memory limit |
| `admissionController.serviceMonitor.enabled` | `true` | Prometheus metrics |
| `backgroundController.resources.requests.cpu` | `100m` | CPU request |
| `backgroundController.resources.limits.memory` | `256Mi` | Memory limit |
| `backgroundController.serviceMonitor.enabled` | `true` | Prometheus metrics |
| `cleanupController.resources.limits.cpu` | `250m` | CPU limit |
| `reportsController.resources.limits.cpu` | `250m` | CPU limit |

## Common Operations and Troubleshooting

| Task | Command |
|---|---|
| List cluster policies | `kubectl get clusterpolicy` |
| Check policy status | `kubectl describe clusterpolicy <name>` |
| View policy reports | `kubectl get policyreport -A` |
| View cluster policy reports | `kubectl get clusterpolicyreport` |
| Check admission controller | `kubectl get pods -n kyverno -l app.kubernetes.io/component=admission-controller` |
| View admission logs | `kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller` |
| Test policy (dry-run) | `kubectl apply --dry-run=server -f <resource.yaml>` |
| Force ArgoCD re-sync | `argocd app sync kyverno` |

**Common issues:**
- **All resource creation blocked**: The admission webhook may be down. Check pod status and consider setting `failurePolicy: Ignore`.
- **Policy not enforcing**: Verify the policy `validationFailureAction` is set to `Enforce`, not `Audit`.
- **High memory on admission controller**: Complex policies with many `match` conditions can be memory-intensive. Increase limits or simplify policies.

## Official Documentation

- Kyverno docs: <https://kyverno.io/docs/>
- Policy library: <https://kyverno.io/policies/>
- Helm chart: <https://github.com/kyverno/kyverno/tree/main/charts/kyverno>
- Writing policies: <https://kyverno.io/docs/writing-policies/>
