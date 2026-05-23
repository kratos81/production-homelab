# Platform URLs & Credentials

## SSO (Keycloak)

| Field | Value |
|-------|-------|
| URL | https://keycloak.homelab.local |
| Admin User | admin |
| Admin Password | CHANGE_ME_KEYCLOAK_ADMIN |
| Realm | homelab |

### SSO User

| Field | Value |
|-------|-------|
| Username | user |
| Password | CHANGE_ME_USER_PASSWORD |
| Groups | /admins |

SSO is configured for: ArgoCD, Grafana, Harbor, GitLab, Mattermost, JupyterHub

---

## Application Credentials

### Mattermost
| Field | Value |
|-------|-------|
| URL | https://mattermost.homelab.local |
| User | sreadmin |
| Password | CHANGE_ME_GRAFANA_ADMIN |
| Role | system_admin |

### ArgoCD
| Field | Value |
|-------|-------|
| URL | https://argocd.homelab.local |
| Admin User | admin |
| Admin Password | CHANGE_ME_ARGOCD_ADMIN_PASSWORD |
| SSO | Keycloak OIDC |

### Grafana
| Field | Value |
|-------|-------|
| URL | https://grafana.homelab.local |
| Admin User | admin |
| Admin Password | CHANGE_ME_GRAFANA_ADMIN |
| SSO | Keycloak OIDC |

### Vault
| Field | Value |
|-------|-------|
| URL | https://vault.homelab.local |
| Root Token | CHANGE_ME_VAULT_ROOT_TOKEN |
| Unseal Key | CHANGE_ME_VAULT_UNSEAL_KEY |

### Harbor
| Field | Value |
|-------|-------|
| URL | https://harbor.homelab.local |
| Admin User | admin |
| Admin Password | CHANGE_ME_HARBOR_ADMIN |
| SSO | Keycloak OIDC |

### GitLab
| Field | Value |
|-------|-------|
| URL | https://gitlab.homelab.local |
| Admin User | root |
| Admin Password | CHANGE_ME_GITLAB_ROOT_PASSWORD |
| SSO | Keycloak OIDC |

### MinIO
| Field | Value |
|-------|-------|
| Console URL | https://minio-console.homelab.local |
| API URL | https://minio.homelab.local |
| Root User | admin |
| Root Password | CHANGE_ME_MINIO_ADMIN |

### NeuVector
| Field | Value |
|-------|-------|
| URL | https://neuvector.homelab.local |
| Admin User | admin |
| Admin Password | admin (change on first login) |

### Litmus Chaos
| Field | Value |
|-------|-------|
| URL | Internal only (no ingress) |
| Admin User | admin |
| Admin Password | litmus |

### Rancher
| Field | Value |
|-------|-------|
| URL | https://rancher.homelab.local |
| Admin User | admin |
| Bootstrap Password | RancherAdmin2024 |

---

## No-Auth / SSO-Only URLs

| Application | URL |
|-------------|-----|
| OpenCost | https://opencost.homelab.local |
| Open WebUI (AI Chat) | https://chat.homelab.local |
| JupyterHub | https://jupyter.homelab.local |
| MLflow | https://mlflow.homelab.local |
| Ollama API | https://ollama.homelab.local |
| Argo Workflows | https://argo-workflows.homelab.local |
| Milvus | https://milvus.homelab.local |
| Sample App | https://sample-app.homelab.local |
| Argo Rollouts Dashboard | https://rollouts.homelab.local |

---

## Infrastructure

| Component | IP / URL |
|-----------|----------|
| Proxmox VE | 10.0.0.1 |
| Rancher Management | 10.0.0.50 |
| RKE2 Control Plane | 10.0.0.10 |
| Workers | 10.0.0.11-107 |
| Ingress VIP (MetalLB) | 10.0.1.200 |
| CoreDNS (external-dns) | 10.0.1.210 |
| k3s Practice VM (Fedora 41) | 10.0.0.21 |

## Alert Pipeline

```
Prometheus → AlertManager → Webhook Forwarder → Mattermost #sre-alerts
```

Webhook ID: `CHANGE_ME_MATTERMOST_WEBHOOK_ID`
