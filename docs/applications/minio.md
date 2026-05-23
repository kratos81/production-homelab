# MinIO - S3-Compatible Object Storage

## Overview

MinIO provides S3-compatible object storage for the platform. It serves as the central artifact and data store for MLflow experiments, Milvus vector data, Velero backups, Argo Workflows artifacts, and JupyterHub data.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on Proxmox VE
- **Mode**: Standalone (single instance)
- **Namespace**: `minio`
- **API Endpoint**: `https://minio.homelab.local` via NGINX ingress with TLS
- **Console**: `https://minio-console.homelab.local` via NGINX ingress with TLS
- **Storage**: 50Gi persistent volume
- **Monitoring**: ServiceMonitor enabled for Prometheus scraping
- **Pre-configured Buckets**: `mlflow`, `jupyterhub`, `models`, `velero`, `milvus`, `argo-workflows`

## Best Practices

### Security
- Move `rootUser` and `rootPassword` out of `values.yaml` into a Kubernetes Secret referenced via `existingSecret`
- Create dedicated service accounts with scoped policies for each application instead of sharing root credentials
- Enable bucket versioning on critical buckets (`mlflow`, `models`) to protect against accidental deletion
- Consider enabling server-side encryption (SSE) for sensitive data

### Performance
- Standalone mode is suitable for development and small-scale production; for high availability, switch to distributed mode with at least 4 nodes
- The 50Gi volume should be monitored; MLflow artifacts and model files can grow rapidly
- Resource limits (1 CPU / 2Gi) are adequate for moderate throughput; increase for heavy concurrent access

### Reliability
- The `velero` bucket is used for cluster backups -- ensure this bucket has lifecycle policies and sufficient capacity
- Enable bucket replication to an off-cluster MinIO instance for disaster recovery
- Monitor disk usage alerts at the `storageMinimalAvailablePercentage` threshold

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `mode` | `standalone` | Deployment mode |
| `replicas` | `1` | Number of MinIO instances |
| `rootUser` | `admin` | Root access key |
| `persistence.size` | `50Gi` | Storage volume size |
| `ingress.hosts[0]` | `minio.homelab.local` | API endpoint hostname |
| `consoleIngress.hosts[0]` | `minio-console.homelab.local` | Console hostname |
| `resources.limits` | 1 CPU / 2Gi | Pod resource limits |
| `buckets` | 6 pre-created buckets | Auto-provisioned buckets |

## Common Operations and Troubleshooting

```bash
# Check MinIO pod status
kubectl -n minio get pods

# View MinIO logs
kubectl -n minio logs -l app=minio

# Access MinIO client inside the cluster
kubectl -n minio run mc --rm -it --image=minio/mc -- sh
# Then: mc alias set local http://minio.minio.svc.cluster.local:9000 admin CHANGE_ME_MINIO_ADMIN

# List buckets
mc ls local/

# Check bucket disk usage
mc du local/mlflow

# Verify connectivity from other namespaces
kubectl -n ai-platform run curl --rm -it --image=curlimages/curl -- \
  curl -s http://minio.minio.svc.cluster.local:9000/minio/health/live

# Monitor storage usage
kubectl -n minio exec -it deploy/minio -- df -h /data
```

## Official Documentation

- MinIO Kubernetes Docs: https://min.io/docs/minio/kubernetes/upstream/
- MinIO Helm Chart: https://github.com/minio/minio/tree/master/helm/minio
- MinIO Client Reference: https://min.io/docs/minio/linux/reference/minio-mc.html
