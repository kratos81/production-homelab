# ArgoCD - GitOps Continuous Delivery

## Overview

ArgoCD is the GitOps engine for this platform, providing declarative continuous delivery for all Kubernetes applications. It monitors the `infra` Git repository and automatically reconciles cluster state with the desired state defined in manifests and Helm values.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on VMware vSphere / vCenter
- **Namespace**: `argocd`
- **Ingress**: `https://argocd.homelab.local` via NGINX ingress with TLS (cert-manager `homelab-ca-issuer`)
- **Authentication**: Keycloak OIDC integration (`https://keycloak.homelab.local/realms/homelab`)
- **RBAC**: Keycloak `/admins` group mapped to `role:admin`; default is `role:readonly`
- **Monitoring**: ServiceMonitors enabled on server, controller, and repo-server for Prometheus scraping

## Best Practices

### Security
- OIDC is configured with Keycloak -- avoid using the built-in `admin` account for day-to-day operations
- `server.insecure` is set to `false`; TLS termination uses SSL passthrough at the ingress level
- Move `oidc.config.clientSecret` to a Kubernetes Secret or external secret manager instead of storing it in `values.yaml`
- Set `oidc.tls.insecure.skip.verify` to `false` once internal CA certificates are properly distributed

### Performance
- Controller resource limits (1 CPU / 1Gi) are appropriate for moderate workloads (~50 applications)
- Repo-server has 2Gi memory limit to handle large Helm charts and Kustomize overlays
- If sync times increase, consider increasing repo-server replicas or adding sharding to the controller

### Reliability
- All ArgoCD Applications should use `selfHeal: true` and `prune: true` in sync policies
- Use sync waves (`argocd.argoproj.io/sync-wave`) to order dependent deployments
- Configure retry policies with exponential backoff on all Application resources

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `server.ingress.hostname` | `argocd.homelab.local` | ArgoCD UI/API hostname |
| `server.resources.limits` | 500m CPU / 512Mi | Server pod resource limits |
| `controller.resources.limits` | 1 CPU / 1Gi | Application controller limits |
| `repoServer.resources.limits` | 1 CPU / 2Gi | Repo server limits |
| `redis.resources.limits` | 250m CPU / 256Mi | Redis cache limits |
| `configs.params.server.insecure` | `false` | Enforce HTTPS on server |
| `configs.rbac.policy.default` | `role:readonly` | Default RBAC role |
| `configs.cm.url` | `https://argocd.homelab.local` | External URL for OIDC callbacks |

## Common Operations and Troubleshooting

```bash
# Check ArgoCD application sync status
kubectl -n argocd get applications

# Force sync an application
argocd app sync <app-name>

# View controller logs for sync issues
kubectl -n argocd logs -l app.kubernetes.io/component=application-controller

# Retrieve initial admin password (if OIDC is unavailable)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Check repo-server connectivity to Git
kubectl -n argocd logs -l app.kubernetes.io/component=repo-server | grep -i error

# Restart ArgoCD server after config changes
kubectl -n argocd rollout restart deployment argocd-server
```

## Official Documentation

- ArgoCD Docs: https://argo-cd.readthedocs.io/en/stable/
- ArgoCD Helm Chart: https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
- ArgoCD OIDC Configuration: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/#existing-oidc-provider
