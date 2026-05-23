# JupyterHub - Interactive Notebook Environment

## Overview

JupyterHub provides multi-user Jupyter notebook environments for data science and ML experimentation. Each user gets a dedicated notebook server with pre-configured access to Ollama, MLflow, and MinIO services.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on VMware vSphere / vCenter
- **Namespace**: `ai-platform`
- **Endpoint**: `https://jupyter.homelab.local` via NGINX ingress with TLS
- **User Image**: `quay.io/jupyter/scipy-notebook:latest`
- **Default Interface**: JupyterLab (`/lab`)
- **User Storage**: 5Gi per user on Longhorn StorageClass with dynamic provisioning
- **Authentication**: DummyAuthenticator (development only)
- **Deployment**: Managed via ArgoCD Application with sync wave `14`, ServerSideApply enabled
- **Helm Chart**: `jupyterhub` from `https://hub.jupyter.org/helm-chart/` (version `4.*`)

## Best Practices

### Security
- **CRITICAL**: Replace `DummyAuthenticator` with a production authenticator (Keycloak OIDC recommended)
- Move `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from `extraEnv` to Kubernetes Secrets
- Move `DummyAuthenticator.password` to a Kubernetes Secret
- Apply network policies to restrict notebook server egress to only required services
- Consider using `singleuser.profileList` to offer different resource tiers

### Performance
- User pods are guaranteed 0.5 CPU / 1G memory with limits of 2 CPU / 4G memory
- The `scipy-notebook` image includes NumPy, Pandas, SciPy, and Matplotlib
- For GPU workloads, add a separate profile with GPU-enabled images and resource requests
- User scheduler is disabled; enable it if fair scheduling across many users is needed

### Reliability
- User storage on Longhorn provides replication and snapshot capabilities
- Hub pod has 1Gi memory limit; increase if user count exceeds ~50
- Idle culler is not configured; enable `cull.enabled` to reclaim resources from inactive notebooks
- The unlimited `proxy-body-size` supports large file uploads to notebooks

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `hub.config.authenticator_class` | `dummy` | Authentication method |
| `hub.resources.limits` | 1 CPU / 1Gi | Hub pod limits |
| `singleuser.cpu.guarantee` | `0.5` | Guaranteed CPU per user |
| `singleuser.memory.guarantee` | `1G` | Guaranteed RAM per user |
| `singleuser.cpu.limit` | `2` | Max CPU per user |
| `singleuser.memory.limit` | `4G` | Max RAM per user |
| `singleuser.storage.capacity` | `5Gi` | Persistent volume per user |
| `singleuser.storage.dynamic.storageClass` | `longhorn` | Storage backend |
| `singleuser.extraEnv.OLLAMA_HOST` | `http://ollama....:11434` | Ollama API endpoint |
| `singleuser.extraEnv.MLFLOW_TRACKING_URI` | `http://mlflow....:5000` | MLflow tracking server |
| `ingress.hosts[0]` | `jupyter.homelab.local` | External hostname |

## Common Operations and Troubleshooting

```bash
# Check hub and user pods
kubectl -n ai-platform get pods -l app=jupyterhub

# View hub logs
kubectl -n ai-platform logs -l component=hub -f

# List active user servers
kubectl -n ai-platform get pods -l component=singleuser-server

# Restart a stuck user server
kubectl -n ai-platform delete pod jupyter-<username>

# Check user PVC usage
kubectl -n ai-platform get pvc -l component=singleuser-storage

# Test MLflow connectivity from a notebook pod
kubectl -n ai-platform exec -it jupyter-admin -- \
  curl -s http://mlflow.ai-platform.svc.cluster.local:5000/api/2.0/mlflow/experiments/list

# Force ArgoCD resync
argocd app sync jupyterhub
```

## Official Documentation

- JupyterHub on Kubernetes: https://z2jh.jupyter.org/en/stable/
- JupyterHub Helm Chart: https://hub.jupyter.org/helm-chart/
- JupyterHub Configuration Reference: https://jupyterhub.readthedocs.io/en/stable/reference/config-reference.html
