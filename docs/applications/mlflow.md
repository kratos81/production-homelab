# MLflow - Experiment Tracking and Model Registry

## Overview

MLflow provides experiment tracking, model versioning, and artifact storage for ML workflows. It integrates with MinIO for S3-compatible artifact storage and is accessible from JupyterHub notebooks and Argo Workflows pipelines.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on Harvester HCI
- **Namespace**: `ai-platform`
- **Endpoint**: `https://mlflow.homelab.local` via NGINX ingress with TLS
- **Internal Service**: `http://mlflow.ai-platform.svc.cluster.local:5000`
- **Artifact Store**: MinIO S3 bucket `mlflow` at `http://minio.minio.svc.cluster.local:9000`
- **Backend Store**: Database (migration disabled in current config)
- **Monitoring**: ServiceMonitor enabled for Prometheus scraping

## Best Practices

### Security
- Move MinIO credentials (`awsAccessKeyId`, `awsSecretAccessKey`) to a Kubernetes Secret referenced via `existingSecret`
- MLflow has no built-in authentication; add ingress-level auth annotations or deploy an auth proxy
- Consider restricting ingress access with `nginx.ingress.kubernetes.io/whitelist-source-range` for internal-only access
- Use dedicated MinIO service accounts with write access scoped to the `mlflow` bucket only

### Performance
- Resource limits (1 CPU / 1Gi) are suitable for moderate experiment tracking (~100 concurrent runs)
- Large artifacts (model files >1GB) are stored directly in MinIO, keeping MLflow server lightweight
- Enable database connection pooling if tracking query latency increases
- `MLFLOW_S3_IGNORE_TLS` is set to `true` for internal MinIO communication; this is appropriate for in-cluster traffic

### Reliability
- Artifacts in MinIO persist independently of the MLflow server; server restarts do not lose data
- Database migration is disabled (`databaseMigration: false`); enable manually during upgrades
- Back up the MLflow database regularly via Velero or pg_dump to prevent experiment metadata loss

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `artifactRoot.s3.bucket` | `mlflow` | MinIO bucket for artifacts |
| `artifactRoot.s3.enabled` | `true` | S3 artifact storage enabled |
| `extraEnvVars.MLFLOW_S3_ENDPOINT_URL` | `http://minio.minio.svc...:9000` | MinIO endpoint |
| `extraEnvVars.MLFLOW_S3_IGNORE_TLS` | `true` | Skip TLS for internal S3 |
| `resources.limits` | 1 CPU / 1Gi | Pod resource limits |
| `serviceMonitor.enabled` | `true` | Prometheus metrics enabled |
| `ingress.hosts[0].host` | `mlflow.homelab.local` | External hostname |
| `backendStore.databaseMigration` | `false` | Auto-migration disabled |

## Common Operations and Troubleshooting

```bash
# Check MLflow pod status
kubectl -n ai-platform get pods -l app.kubernetes.io/name=mlflow

# View MLflow server logs
kubectl -n ai-platform logs -l app.kubernetes.io/name=mlflow -f

# Test MLflow API
curl -s https://mlflow.homelab.local/api/2.0/mlflow/experiments/list | jq '.experiments[].name'

# Verify MinIO connectivity from MLflow pod
kubectl -n ai-platform exec -it deploy/mlflow -- \
  curl -s http://minio.minio.svc.cluster.local:9000/minio/health/live

# List artifacts in MinIO mlflow bucket
mc ls minio-local/mlflow/

# Check experiment count
curl -s https://mlflow.homelab.local/api/2.0/mlflow/experiments/search | jq '.experiments | length'

# Run database migration manually during upgrades
kubectl -n ai-platform exec -it deploy/mlflow -- mlflow db upgrade
```

## Official Documentation

- MLflow Docs: https://mlflow.org/docs/latest/index.html
- MLflow Tracking Server: https://mlflow.org/docs/latest/tracking.html
- MLflow S3 Artifact Store: https://mlflow.org/docs/latest/tracking/artifacts-stores.html#amazon-s3-and-s3-compatible-storage
