# Longhorn - Distributed Block Storage

## Overview

Longhorn provides distributed block storage for Kubernetes, offering persistent volumes with built-in replication, snapshots, and backup capabilities. It serves as the primary storage backend for stateful workloads including JupyterHub user volumes and other applications that require replicated storage beyond `local-path`.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on Harvester HCI
- **Namespace**: `longhorn-system`
- **UI Endpoint**: `https://longhorn.homelab.local` via NGINX ingress with TLS
- **Default Replica Count**: 2 (data replicated across 2 nodes)
- **Reclaim Policy**: Retain (volumes preserved after PVC deletion)
- **Data Locality**: best-effort (prefer local replica for read performance)
- **Node Down Policy**: delete both StatefulSet and Deployment pods for faster failover

## Best Practices

### Security
- Longhorn UI has no built-in authentication; add ingress-level basic auth or OIDC proxy
- Use `storageMinimalAvailablePercentage` (set to 15%) to prevent disk exhaustion
- The Retain reclaim policy prevents accidental data loss but requires manual cleanup of unused volumes
- Restrict Longhorn UI access to cluster administrators only

### Performance
- 2 replicas provide a good balance between redundancy and write performance on Harvester HCI
- `defaultDataLocality: best-effort` ensures reads are served from the local replica when possible
- For write-intensive workloads, consider setting data locality to `disabled` to allow any replica to serve writes
- Longhorn Manager resources (500m CPU / 512Mi) are sufficient for clusters with up to 100 volumes
- Monitor Longhorn volume rebuild times; slow rebuilds indicate disk I/O pressure

### Reliability
- `defaultClassReplicaCount: 2` ensures all dynamically provisioned volumes have redundancy
- `nodeDownPodDeletionPolicy: delete-both-statefulset-and-deployment-pod` enables faster failover when a node goes down
- `createDefaultDiskLabeledNodes: true` automatically configures new nodes for Longhorn storage
- `persistence.defaultClass: false` -- Longhorn is not the default StorageClass; workloads must explicitly request `storageClass: longhorn`
- Configure recurring snapshot and backup schedules via the Longhorn UI or CRDs

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `defaultSettings.defaultReplicaCount` | `2` | Replicas per volume |
| `defaultSettings.storageMinimalAvailablePercentage` | `15` | Minimum free disk percentage |
| `defaultSettings.defaultDataLocality` | `best-effort` | Data locality strategy |
| `defaultSettings.nodeDownPodDeletionPolicy` | `delete-both-...` | Node failure handling |
| `defaultSettings.createDefaultDiskLabeledNodes` | `true` | Auto-configure nodes |
| `persistence.defaultClass` | `false` | Not default StorageClass |
| `persistence.defaultClassReplicaCount` | `2` | StorageClass replica count |
| `persistence.reclaimPolicy` | `Retain` | Volume reclaim policy |
| `ingress.host` | `longhorn.homelab.local` | UI hostname |
| `longhornManager.resources.limits` | 500m CPU / 512Mi | Manager limits |

## Common Operations and Troubleshooting

```bash
# Check Longhorn system pods
kubectl -n longhorn-system get pods

# List all Longhorn volumes
kubectl -n longhorn-system get volumes.longhorn.io

# Check volume health
kubectl -n longhorn-system get volumes.longhorn.io -o custom-columns=NAME:.metadata.name,STATE:.status.state,ROBUSTNESS:.status.robustness

# View Longhorn Manager logs
kubectl -n longhorn-system logs -l app=longhorn-manager --tail=100

# Trigger a snapshot for a specific volume
kubectl -n longhorn-system apply -f - <<EOF
apiVersion: longhorn.io/v1beta2
kind: Snapshot
metadata:
  name: manual-snap-$(date +%s)
spec:
  volume: <volume-name>
EOF

# Check node storage availability
kubectl -n longhorn-system get nodes.longhorn.io -o custom-columns=NAME:.metadata.name,AVAIL:.status.diskStatus

# Force delete a stuck volume
kubectl -n longhorn-system delete volume.longhorn.io <volume-name> --grace-period=0
```

## Official Documentation

- Longhorn Docs: https://longhorn.io/docs/
- Longhorn Helm Chart: https://github.com/longhorn/charts
- Longhorn Best Practices: https://longhorn.io/docs/latest/best-practices/
- Longhorn on Harvester: https://docs.harvesterhci.io/v1.2/advanced/longhorn
