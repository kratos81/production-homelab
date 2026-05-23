# cert-manager - Certificate Management with Self-Signed CA

## Overview

cert-manager automates the issuance and renewal of TLS certificates within Kubernetes. On this platform, it operates with a self-signed CA (`homelab-ca-issuer`) to provide TLS certificates for all internal services, eliminating the need for an external CA while maintaining encrypted communication across the cluster.

## Architecture on This Platform

- **Deployment model**: Helm chart v1.16.x deployed via ArgoCD (`sync-wave: 1`), deployed after MetalLB and before applications that need TLS.
- **Namespace**: `cert-manager`
- **Issuer type**: `ClusterIssuer` named `homelab-ca-issuer` -- a self-signed CA that issues certificates cluster-wide.
- **CRDs**: Installed via Helm (`installCRDs: true`).
- **Consumers**: Vault, Harbor, Keycloak, NeuVector, and any Ingress annotated with `cert-manager.io/cluster-issuer: homelab-ca-issuer`.
- **Retry policy**: ArgoCD retries up to 3 times with exponential backoff (30s, 60s, 120s, max 5m).

## Best Practices

### Security
- Store the CA private key in a Kubernetes Secret with restricted RBAC. Only cert-manager should access it.
- Rotate the self-signed CA periodically and re-issue downstream certificates.
- Distribute the CA certificate to all clients that need to trust internal services (browsers, CLI tools, other clusters).
- Consider migrating to a proper PKI (e.g., Vault PKI backend) for production-grade certificate management.

### Performance
- Resource limits are set conservatively (controller: 250m/256Mi, webhook: 100m/128Mi, cainjector: 250m/256Mi). Monitor and adjust if certificate issuance is slow.
- The cainjector watches all namespaces for `Certificate` resources -- in large clusters, this can be memory-intensive.

### Reliability
- ArgoCD `selfHeal: true` ensures CRDs and controllers are restored if accidentally deleted.
- The retry policy handles transient failures during initial deployment or CRD registration.
- Monitor `Certificate` and `CertificateRequest` resources for failed issuance.

## Configuration Reference

### ArgoCD Application (`cert-manager.yaml`)

| Setting | Value | Purpose |
|---|---|---|
| `chart` | `cert-manager` | Jetstack official chart |
| `targetRevision` | `v1.16.*` | Pin to 1.16.x |
| `namespace` | `cert-manager` | Standard namespace |
| `sync-wave` | `1` | Deploy after MetalLB |
| `retry.limit` | `3` | Retry on transient errors |

### Values (`cert-manager-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `installCRDs` | `true` | Install CRDs via Helm |
| `resources.requests.cpu` | `100m` | Controller CPU request |
| `resources.requests.memory` | `128Mi` | Controller memory request |
| `webhook.resources.requests.cpu` | `50m` | Webhook CPU request |
| `cainjector.resources.requests.cpu` | `100m` | CA injector CPU request |

## Common Operations and Troubleshooting

| Task | Command |
|---|---|
| List certificates | `kubectl get certificates -A` |
| Check certificate status | `kubectl describe certificate <name> -n <namespace>` |
| View issuer status | `kubectl get clusterissuer` |
| Check cert-manager logs | `kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager` |
| Manually trigger renewal | `kubectl delete secret <tls-secret> -n <namespace>` |
| View certificate requests | `kubectl get certificaterequests -A` |
| Force ArgoCD re-sync | `argocd app sync cert-manager` |

**Common issues:**
- **Certificate stuck at `False` ready**: Check `CertificateRequest` and `Order` resources for error messages. Verify the `ClusterIssuer` is ready.
- **Webhook timeout errors**: The webhook pod may not be ready. Check webhook pod logs and ensure its Service is reachable.
- **CRD conflicts on upgrade**: If CRDs were previously installed manually, Helm may conflict. Remove old CRDs before upgrading.

## Official Documentation

- cert-manager docs: <https://cert-manager.io/docs/>
- Self-signed issuers: <https://cert-manager.io/docs/configuration/selfsigned/>
- CA issuers: <https://cert-manager.io/docs/configuration/ca/>
- Troubleshooting: <https://cert-manager.io/docs/troubleshooting/>
