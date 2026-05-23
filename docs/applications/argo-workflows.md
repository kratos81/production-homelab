# Argo Workflows - ML Pipeline Orchestration

## Overview

Argo Workflows provides container-native workflow orchestration for ML pipelines, data processing, and CI/CD tasks. It integrates with MinIO for artifact storage and can trigger model training, evaluation, and deployment pipelines.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on Proxmox VE
- **Namespace**: `argo-workflows`
- **UI Endpoint**: `https://argo-workflows.homelab.local` via NGINX ingress with TLS
- **Artifact Repository**: MinIO S3 bucket `argo-workflows` at `minio.minio.svc.cluster.local:9000`
- **Credentials**: MinIO access keys stored in Kubernetes Secret `argo-workflows-minio`
- **Monitoring**: ServiceMonitor and metricsConfig enabled for Prometheus scraping

## Best Practices

### Security
- MinIO credentials are stored in a Kubernetes Secret (`argo-workflows-minio`) -- ensure this Secret is managed via sealed-secrets or an external secret manager
- Configure RBAC to restrict who can submit workflows; use Argo Workflows SSO integration with Keycloak
- Use `serviceAccountName` in workflow templates to scope pod permissions per workflow type
- Apply resource quotas on the workflow namespace to prevent runaway pipelines from consuming cluster resources

### Performance
- Controller resources (500m CPU / 512Mi) are adequate for ~50 concurrent workflows
- The server is lightweight (250m CPU / 256Mi); scale if many users access the UI simultaneously
- Use workflow-level `parallelism` to limit concurrent steps and prevent resource contention
- Configure `activeDeadlineSeconds` on workflows to auto-terminate long-running jobs
- Use `volumeClaimTemplates` with Longhorn for workflow steps that need shared persistent storage

### Reliability
- Artifact persistence in MinIO ensures workflow outputs survive pod evictions
- Configure `retryStrategy` on individual workflow steps for transient failure recovery
- Set `podGarbageCollection` to clean up completed pods and prevent resource exhaustion
- Use `workflowTemplateRef` to version and reuse pipeline definitions

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `controller.resources.limits` | 500m CPU / 512Mi | Controller pod limits |
| `controller.metricsConfig.enabled` | `true` | Prometheus metrics enabled |
| `server.resources.limits` | 250m CPU / 256Mi | Server pod limits |
| `server.ingress.hosts[0]` | `argo-workflows.homelab.local` | UI hostname |
| `artifactRepository.s3.bucket` | `argo-workflows` | MinIO bucket for artifacts |
| `artifactRepository.s3.endpoint` | `minio.minio.svc...:9000` | MinIO endpoint |
| `artifactRepository.s3.insecure` | `true` | HTTP for in-cluster MinIO |
| `artifactRepository.s3.accessKeySecret` | `argo-workflows-minio` | Credentials Secret name |

## Common Operations and Troubleshooting

```bash
# Check controller and server pods
kubectl -n argo-workflows get pods

# List running workflows
argo -n argo-workflows list --running

# Submit a workflow
argo -n argo-workflows submit workflow.yaml

# View workflow logs
argo -n argo-workflows logs <workflow-name>

# Check controller logs for errors
kubectl -n argo-workflows logs -l app.kubernetes.io/component=controller

# Verify MinIO artifact access
kubectl -n argo-workflows exec -it deploy/argo-workflows-server -- \
  curl -s http://minio.minio.svc.cluster.local:9000/minio/health/live

# Clean up completed workflows older than 7 days
argo -n argo-workflows delete --completed --older 7d

# Check artifact storage usage
mc du minio-local/argo-workflows/
```

## Official Documentation

- Argo Workflows Docs: https://argo-workflows.readthedocs.io/en/latest/
- Argo Workflows Helm Chart: https://github.com/argoproj/argo-helm/tree/main/charts/argo-workflows
- Argo Workflows S3 Artifacts: https://argo-workflows.readthedocs.io/en/latest/configure-artifact-repository/
- Argo Workflows Examples: https://github.com/argoproj/argo-workflows/tree/main/examples
