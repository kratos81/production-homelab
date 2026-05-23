# CloudNativePG - Kubernetes-Native PostgreSQL Operator

## Overview

CloudNativePG (CNPG) is a Kubernetes operator that manages the full lifecycle of PostgreSQL clusters natively within Kubernetes. It handles automated failover, continuous backup, rolling updates, and monitoring without relying on external tools or sidecar containers. On this platform, CNPG is deployed as the operator only -- individual PostgreSQL clusters are created on-demand by applying `Cluster` CRDs. It is intended as the future replacement for bitnami PostgreSQL Helm chart dependencies (GitLab, Keycloak, Feast) to eliminate Docker Hub rate-limiting issues and improve high availability.

## Architecture on This Platform

- **Deployment model**: Helm chart deployed via ArgoCD (sync-wave 3, early in the deployment order since databases are foundational).
- **Namespace**: `cnpg-system` (operator). PostgreSQL clusters are created in application namespaces.
- **Components**:
  - **CNPG Operator** (1 replica): Watches `Cluster` CRDs and manages PostgreSQL instance lifecycle.
- **Monitoring**: Prometheus PodMonitor enabled with label `release: prometheus`.
- **Grafana**: Dashboard auto-created with `grafana_dashboard: "1"` label.

## Creating a PostgreSQL Cluster

### Basic Example

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: my-app-db
  namespace: my-app
spec:
  instances: 3
  primaryUpdateStrategy: unsupervised

  storage:
    size: 10Gi
    storageClass: local-path

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 1Gi
      cpu: 500m

  monitoring:
    enablePodMonitor: true
    podMonitorMetricRelabelings:
      - sourceLabels: [cluster]
        targetLabel: cnpg_cluster

  postgresql:
    parameters:
      shared_buffers: "256MB"
      max_connections: "100"
```

### With Backup to MinIO

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: my-app-db
  namespace: my-app
spec:
  instances: 3
  storage:
    size: 10Gi

  backup:
    barmanObjectStore:
      destinationPath: s3://cnpg-backups/my-app-db
      endpointURL: https://minio.homelab.local
      s3Credentials:
        accessKeyId:
          name: minio-creds
          key: ACCESS_KEY_ID
        secretAccessKey:
          name: minio-creds
          key: SECRET_ACCESS_KEY
    retentionPolicy: "7d"

  scheduledBackup:
    - name: daily-backup
      schedule: "0 0 2 * * *"
      backupOwnerReference: self
```

## Best Practices

### Security
- Use Kubernetes Secrets for PostgreSQL superuser and application credentials -- CNPG generates these automatically.
- Enable TLS for client connections by setting `postgresql.pg_hba` entries.
- Store backup credentials in Vault and sync to Kubernetes Secrets via External Secrets Operator.

### Performance
- Set `shared_buffers` to 25% of the pod's memory limit.
- Use `local-path` or `longhorn` storage classes with ReadWriteOnce access mode for best I/O performance.
- CNPG uses streaming replication -- replicas serve read queries, reducing primary load.
- Monitor via the auto-created Grafana dashboard for query performance and connection pool usage.

### Reliability
- Always deploy 3 instances for production workloads (1 primary + 2 replicas) for automatic failover.
- Configure `primaryUpdateStrategy: unsupervised` for zero-downtime rolling updates.
- Set up scheduled backups to MinIO for point-in-time recovery.
- CNPG handles failover automatically -- the operator promotes a replica within seconds if the primary fails.

## Configuration Reference

### Operator Values (`cloudnative-pg-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `replicaCount` | `1` | Single operator replica |
| `resources.requests.memory` | `256Mi` | Operator memory request |
| `resources.limits.memory` | `512Mi` | Operator memory limit |
| `monitoring.podMonitorEnabled` | `true` | Prometheus PodMonitor |
| `monitoring.grafanaDashboard.create` | `true` | Auto-create Grafana dashboard |
| `config.data.INHERITED_ANNOTATIONS` | `cert-manager.io/*` | Pass cert-manager annotations to managed pods |

## Useful Commands

| Task | Command |
|---|---|
| List PostgreSQL clusters | `kubectl get clusters.postgresql.cnpg.io -A` |
| Check cluster status | `kubectl get cluster <name> -n <ns> -o yaml` |
| View cluster events | `kubectl describe cluster <name> -n <ns>` |
| Connect to primary | `kubectl exec -it <cluster>-1 -n <ns> -- psql` |
| Trigger manual backup | `kubectl apply -f backup.yaml` (create a `Backup` CR) |
| Check operator logs | `kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg` |
| Promote a replica | `kubectl cnpg promote <cluster> <instance> -n <ns>` |
| Install kubectl plugin | `brew install kubectl-cnpg` |

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Operator CrashLoopBackOff | CRD version mismatch after upgrade | Delete operator pod to restart; check CRD versions |
| Cluster stuck in "Setting up primary" | PVC not binding | Check `kubectl get pvc -n <ns>` and storage class availability |
| Failover not happening | Only 1 instance configured | Set `instances: 3` for automatic failover |
| Backup failing | MinIO credentials incorrect or bucket doesn't exist | Verify S3 credentials and create the bucket in MinIO |
| High WAL accumulation | Backup not running or failing | Check scheduled backup status and barman logs |

## Migration Path from Bitnami PostgreSQL

To migrate GitLab, Keycloak, or Feast from bitnami PostgreSQL to CNPG:

1. Create a CNPG `Cluster` in the application namespace.
2. Use `pg_dump` from the bitnami pod to export the database.
3. Use `pg_restore` or `psql` to import into the CNPG primary.
4. Update the application's database connection string to point to `<cluster>-rw.<namespace>.svc`.
5. Remove the bitnami PostgreSQL StatefulSet from the Helm values.

## Related Components

- **MinIO** -- S3-compatible storage for PostgreSQL backups via Barman.
- **Prometheus** -- Collects PostgreSQL metrics via PodMonitor.
- **Grafana** -- Auto-created dashboard for PostgreSQL cluster monitoring.
- **Longhorn / local-path** -- Storage backends for PostgreSQL data volumes.
- **GitLab, Keycloak, Feast** -- Applications that currently use bitnami PostgreSQL and can migrate to CNPG.
