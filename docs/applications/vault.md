# HashiCorp Vault - Secrets Management

## Overview

HashiCorp Vault provides centralized secrets management, encryption as a service, and identity-based access for this platform. It runs in standalone mode with file-based storage and exposes a web UI for administration. The Vault Agent Injector is disabled in favor of direct API or CSI-based secret access.

## Architecture on This Platform

- **Deployment model**: Official HashiCorp Helm chart deployed via ArgoCD.
- **Namespace**: `vault`
- **Mode**: Standalone (single server, not HA).
- **Storage**: File-based storage at `/vault/data` on a 5Gi PVC using `local-path` StorageClass.
- **TLS**: TLS disabled inside the pod (`tls_disable = 1`); TLS terminated at ingress-nginx with cert-manager certificate.
- **Ingress**: Exposed at `vault.homelab.local` via ingress-nginx with TLS from `homelab-ca-issuer`.
- **Telemetry**: Prometheus metrics enabled with 30s retention, ServiceMonitor labeled `release: prometheus`.
- **UI**: Enabled for web-based administration.
- **Injector**: Disabled -- secrets are not sidecar-injected.

## Best Practices

### Security
- **Unseal keys**: Store unseal keys and the root token securely outside the cluster (e.g., offline storage, HSM). Never commit them to Git.
- Enable audit logging to track all access to secrets.
- Use AppRole, Kubernetes auth, or OIDC auth methods instead of root tokens for day-to-day access.
- Consider enabling TLS within the pod (end-to-end) for defense-in-depth, rather than relying solely on ingress TLS.
- Restrict access to the `vault` namespace and the Vault PVC via RBAC and NetworkPolicy.

### Performance
- File storage is suitable for small to medium workloads. For high-throughput or HA requirements, migrate to Raft integrated storage or Consul backend.
- Resource allocation (250m/256Mi request, 500m/512Mi limit) is appropriate for standalone mode with moderate secret operations.
- Prometheus retention of 30s keeps memory usage low for telemetry.

### Reliability
- **Standalone mode is a single point of failure**. For production, consider migrating to HA mode with Raft storage and 3+ replicas.
- The `local-path` StorageClass ties data to a single node. If that node fails, Vault data is lost unless backed up externally.
- Implement regular backups of `/vault/data` or use `vault operator raft snapshot` (if using Raft).
- After pod restarts, Vault must be manually unsealed (unless auto-unseal is configured with a cloud KMS or Transit engine).

## Configuration Reference

### Values (`vault-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `server.standalone.enabled` | `true` | Standalone deployment |
| `server.standalone.config` | HCL block | Listener, storage, telemetry |
| `server.dataStorage.size` | `5Gi` | PVC size for Vault data |
| `server.dataStorage.storageClass` | `local-path` | Storage class |
| `server.resources.requests.cpu` | `250m` | CPU request |
| `server.resources.limits.memory` | `512Mi` | Memory limit |
| `server.ingress.enabled` | `true` | Expose via ingress |
| `server.ingress.hosts[0].host` | `vault.homelab.local` | External hostname |
| `server.ingress.annotations` | `homelab-ca-issuer` | cert-manager issuer |
| `ui.enabled` | `true` | Enable web UI |
| `injector.enabled` | `false` | Disable sidecar injector |
| `serverTelemetry.serviceMonitor.enabled` | `true` | Prometheus metrics |

### Vault Server Configuration (HCL)

```hcl
ui = true
listener "tcp" {
  tls_disable     = 1
  address         = "[::]:8200"
  cluster_address = "[::]:8201"
}
storage "file" {
  path = "/vault/data"
}
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}
```

## Common Operations and Troubleshooting

| Task | Command |
|---|---|
| Check pod status | `kubectl get pods -n vault` |
| View Vault logs | `kubectl logs -n vault vault-0` |
| Check seal status | `kubectl exec -n vault vault-0 -- vault status` |
| Initialize Vault | `kubectl exec -n vault vault-0 -- vault operator init` |
| Unseal Vault | `kubectl exec -n vault vault-0 -- vault operator unseal <key>` |
| Access UI | Browse to `https://vault.homelab.local` |
| Force ArgoCD re-sync | `argocd app sync vault` |

**Common issues:**
- **Vault sealed after restart**: This is expected. Unseal with stored keys, or configure auto-unseal.
- **PVC not binding**: Verify the `local-path` StorageClass exists and the provisioner is running.
- **503 from ingress**: Vault pod may be sealed or not ready. Check readiness probe and unseal status.
- **Metrics not scraped**: Verify the ServiceMonitor labels match the Prometheus selector (`release: prometheus`).

## Official Documentation

- Vault docs: <https://developer.hashicorp.com/vault/docs>
- Helm chart: <https://developer.hashicorp.com/vault/docs/platform/k8s/helm>
- Standalone configuration: <https://developer.hashicorp.com/vault/docs/configuration>
- Auto-unseal: <https://developer.hashicorp.com/vault/docs/concepts/seal>
