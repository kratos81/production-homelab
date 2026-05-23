# Harbor - Container Registry

## Overview

Harbor is an open-source container registry that provides image storage, vulnerability scanning, content signing, and access control. On this platform, Harbor serves as the private container registry with Trivy-based vulnerability scanning enabled, exposed via ingress-nginx with TLS from cert-manager.

## Architecture on This Platform

- **Deployment model**: Official Harbor Helm chart deployed via ArgoCD.
- **Namespace**: `harbor`
- **Ingress**: Exposed at `harbor.homelab.local` via ingress-nginx with TLS from `homelab-ca-issuer`.
- **Components**: Core, Registry, Portal, JobService, Database (internal PostgreSQL), Redis (internal), Trivy scanner.
- **Notary**: Disabled (content trust/image signing not enabled).
- **Storage**: All components use `local-path` StorageClass -- Registry (50Gi), Database (5Gi), Redis (2Gi), JobService (2Gi).
- **Metrics**: Prometheus metrics and ServiceMonitor enabled, labeled `release: prometheus`.
- **Ingress annotations**: Unlimited proxy body size (`"0"`) and 900s read timeout to support large image pushes.

## Best Practices

### Security
- **CRITICAL**: Move the admin password out of the values file into a Kubernetes Secret managed by an external secrets solution. The current config contains `harborAdminPassword` in plaintext.
- Configure OIDC authentication with Keycloak for user access instead of relying on the built-in admin account.
- Enable robot accounts for CI/CD pipelines with minimal scoped permissions.
- Review Trivy scan results regularly and configure vulnerability policies to block images above a severity threshold.
- Apply network policies to restrict database and Redis access to Harbor components only.

### Performance
- The 50Gi registry PVC should be monitored for capacity. Container images accumulate quickly.
- Configure garbage collection to reclaim space from deleted image layers (Admin Portal > Garbage Collection).
- Ingress annotations set `proxy-body-size: "0"` (unlimited) and `proxy-read-timeout: "900"` to accommodate large image pushes.
- Resource allocations are moderate per component. Monitor Core and Registry under heavy push/pull load.

### Reliability
- Internal PostgreSQL and Redis are single points of failure. For production, consider external managed databases.
- The `local-path` StorageClass ties all PVCs to specific nodes. Node failure means data loss without external backups.
- Back up the PostgreSQL database and registry storage regularly.
- Monitor all component pods -- Harbor has many moving parts and a single unhealthy component can degrade the whole service.

## Configuration Reference

### Key Values (`harbor-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `expose.type` | `ingress` | Expose via Ingress |
| `expose.ingress.hosts.core` | `harbor.homelab.local` | External hostname |
| `expose.ingress.className` | `nginx` | IngressClass |
| `expose.tls.certSource` | `secret` | TLS from cert-manager |
| `externalURL` | `https://harbor.homelab.local` | Registry external URL |
| `persistence.persistentVolumeClaim.registry.size` | `50Gi` | Image storage |
| `persistence.persistentVolumeClaim.database.size` | `5Gi` | Database storage |
| `trivy.enabled` | `true` | Vulnerability scanning |
| `trivy.resources.limits.memory` | `1Gi` | Scanner memory limit |
| `notary.enabled` | `false` | Content trust disabled |
| `metrics.enabled` | `true` | Prometheus metrics |
| `metrics.serviceMonitor.enabled` | `true` | ServiceMonitor for scraping |

### Component Resource Summary

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|---|---|---|---|---|
| Core | 250m | 256Mi | 500m | 512Mi |
| Registry | 250m | 256Mi | 500m | 512Mi |
| Portal | 100m | 128Mi | 250m | 256Mi |
| JobService | 100m | 256Mi | 500m | 512Mi |
| Database | 250m | 256Mi | 500m | 512Mi |
| Redis | 100m | 128Mi | 250m | 256Mi |
| Trivy | 200m | 512Mi | 1 | 1Gi |

## Common Operations and Troubleshooting

| Task | Command |
|---|---|
| Check all pods | `kubectl get pods -n harbor` |
| View core logs | `kubectl logs -n harbor -l component=core` |
| Check registry logs | `kubectl logs -n harbor -l component=registry` |
| Access web UI | Browse to `https://harbor.homelab.local` |
| Docker login | `docker login harbor.homelab.local` |
| Push an image | `docker push harbor.homelab.local/<project>/<image>:<tag>` |
| Check PVC usage | `kubectl get pvc -n harbor` |
| Force ArgoCD re-sync | `argocd app sync harbor` |

**Common issues:**
- **Docker login fails with x509 error**: The self-signed CA must be trusted by the Docker daemon. Add the CA cert to `/etc/docker/certs.d/harbor.homelab.local/ca.crt`.
- **Push fails with 413**: Verify the ingress annotation `proxy-body-size: "0"` is applied.
- **Push timeout**: Large images may exceed default timeouts. The 900s read timeout should handle most cases.
- **Trivy DB update fails**: Scanner needs internet access to download the vulnerability database. Check network policies and proxy settings.
- **Database PVC full**: Increase PVC size or run garbage collection to free space.

## Official Documentation

- Harbor docs: <https://goharbor.io/docs/>
- Helm chart: <https://github.com/goharbor/harbor-helm>
- Trivy scanner: <https://goharbor.io/docs/latest/administration/vulnerability-scanning/>
- Garbage collection: <https://goharbor.io/docs/latest/administration/garbage-collection/>
