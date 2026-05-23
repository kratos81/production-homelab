# CLAUDE.md

## Project Overview

DevSecOps infrastructure platform deployed on-premises using VMware vSphere / vCenter, RKE2 Kubernetes, and ArgoCD GitOps. All 30+ applications are managed declaratively from this repository.

## Repository Structure

```
application/
  apps/           # ArgoCD Application manifests (one per app, sync-wave ordered)
  values/         # Helm values files for each application
    <app>-values.yaml           # Standard naming convention
    <app>-config/               # Directories for raw K8s manifests (non-Helm apps)
sample-app/       # Demo Go application with GitLab CI pipeline (.gitlab-ci.yml)
terraform/        # vSphere VM provisioning (IaC)
```

## Key Conventions

- **ArgoCD apps** use multi-source pattern: Helm chart repo + git ref (`$values`) for values files
- **Sync waves** control deployment order (-3 to 16). See README for rationale. Always assign a wave that respects the dependency chain.
- **All ingresses** use `cert-manager.io/cluster-issuer: homelab-ca-issuer` and `ingressClassName: nginx`
- **Domain**: `*.homelab.local` with self-signed TLS via cert-manager CA
- **Git remote**: `https://github.com/yourorg/production-homelab.git`, branch `main`

## Network

| Resource | IP |
|---|---|
| RKE2 control plane | 10.0.0.10 |
| RKE2 workers | 10.0.0.11-107 |
| Talos VIP (k8s API) | 10.0.0.20 |
| Talos control plane | 10.0.0.21 |
| Talos workers | 10.0.0.22-113 |
| Workload MetalLB pool (RKE2) | 10.0.1.200-220 |
| Talos MetalLB pool | 10.0.1.140-155 |
| Rancher MetalLB pool | 10.0.1.221-225 |
| CoreDNS (external-dns) | 10.0.1.210 |

## SSO

Keycloak (`keycloak.homelab.local`, realm `homelab`) provides OIDC for: ArgoCD, Grafana, Harbor, GitLab, Mattermost, JupyterHub. Clients are defined in the embedded realm JSON in `keycloak-values.yaml`.

## Validation

No test suite. Validate changes with:
1. Python `yaml.safe_load_all()` on all YAML files
2. `json.loads()` on embedded JSON (Keycloak realm, Harbor configureUserSettings, GitLab OIDC secret)
3. `helm template` with the appropriate chart and values file
4. Grafana chart requires `assertNoLeakedSecrets: false` when OIDC client_secret is inline

## Commit Style

- Imperative first line, descriptive (e.g., "Add Keycloak SSO for all apps")
- Bullet-point details in body for multi-change commits
- Always include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
