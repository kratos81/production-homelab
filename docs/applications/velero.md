# Velero - Cluster Backup and Disaster Recovery

## Overview

Velero provides backup, restore, and disaster recovery for Kubernetes cluster resources and persistent volumes. It backs up to the MinIO S3-compatible storage, enabling recovery of namespaces, workloads, and data in case of cluster failures or accidental deletions.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on Proxmox VE
- **Namespace**: `velero`
- **Backup Storage**: MinIO S3 bucket `velero` at `http://minio.minio.svc.cluster.local:9000`
- **Volume Snapshots**: AWS provider with `us-east-1` region (MinIO compatibility)
- **Plugin**: `velero/velero-plugin-for-aws:v1.11.0` (loaded via init container)
- **Node Agent**: Deployed for file-system-level volume backups
- **Schedule**: Daily at 02:00 UTC, 7-day retention, all namespaces

## Best Practices

### Security
- Move MinIO credentials from inline `secretContents` to an externally managed Secret
- The credentials use the MinIO root account; create a dedicated MinIO service account with access scoped to the `velero` bucket only
- Restrict who can create/delete Velero backups using Kubernetes RBAC on Velero CRDs
- Encrypt backups at rest by enabling SSE on the MinIO `velero` bucket

### Performance
- Resource limits (500m CPU / 512Mi) are sufficient for daily scheduled backups
- For large clusters, increase memory limits if backup operations produce OOM errors
- Use `includedNamespaces` selectively instead of `"*"` if certain namespaces contain large volumes that slow backups
- Configure `excludedResources` to skip ephemeral resources (Events, Pods) that do not need backup
- Node Agent enables file-system backups for volumes that do not support snapshots

### Reliability
- The daily backup schedule (02:00 UTC) with 168h (7-day) TTL provides a week of recovery points
- Verify backups regularly by performing test restores to a staging namespace
- Monitor backup completion status; failed backups should trigger alerts
- For critical namespaces, create additional backup schedules with shorter intervals
- Ensure the MinIO `velero` bucket has sufficient capacity for the retention window

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `configuration.backupStorageLocation[0].provider` | `aws` | S3-compatible provider |
| `configuration.backupStorageLocation[0].bucket` | `velero` | MinIO backup bucket |
| `configuration.backupStorageLocation[0].config.s3Url` | `http://minio....:9000` | MinIO endpoint |
| `configuration.backupStorageLocation[0].config.s3ForcePathStyle` | `true` | Required for MinIO |
| `configuration.volumeSnapshotLocation[0].provider` | `aws` | Snapshot provider |
| `deployNodeAgent` | `true` | File-system backup support |
| `schedules.daily-backup.schedule` | `0 2 * * *` | Daily at 02:00 UTC |
| `schedules.daily-backup.template.ttl` | `168h` | 7-day retention |
| `schedules.daily-backup.template.includedNamespaces` | `["*"]` | All namespaces |
| `resources.limits` | 500m CPU / 512Mi | Velero server limits |
| `initContainers[0].image` | `velero-plugin-for-aws:v1.11.0` | AWS/S3 plugin version |

## Common Operations and Troubleshooting

```bash
# Check Velero pods and node agents
kubectl -n velero get pods

# List all backups
velero backup get

# Check backup storage location status
velero backup-location get

# Create an on-demand backup
velero backup create manual-backup --include-namespaces ai-platform --ttl 720h

# Restore from a backup
velero restore create --from-backup daily-backup-<timestamp>

# Restore a single namespace
velero restore create --from-backup daily-backup-<timestamp> --include-namespaces ai-platform

# Check backup logs for errors
velero backup logs <backup-name>

# View scheduled backup status
velero schedule get

# Verify MinIO connectivity
kubectl -n velero exec -it deploy/velero -- \
  curl -s http://minio.minio.svc.cluster.local:9000/minio/health/live

# Check backup sizes in MinIO
mc du minio-local/velero/
```

## Official Documentation

- Velero Docs: https://velero.io/docs/
- Velero Helm Chart: https://github.com/vmware-tanzu/helm-charts/tree/main/charts/velero
- Velero with MinIO: https://velero.io/docs/main/contributions/minio/
- Velero Backup Reference: https://velero.io/docs/main/api-types/backup/
