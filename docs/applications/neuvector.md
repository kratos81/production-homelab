# NeuVector - Runtime Security

## Overview

NeuVector provides full-lifecycle container security including runtime protection, network visibility, vulnerability scanning, and compliance enforcement. It operates as a DaemonSet-based enforcer that monitors container behavior at the network and process level, combined with a centralized controller and web-based manager console.

## Architecture on This Platform

- **Deployment model**: NeuVector core Helm chart v2.7.x deployed via ArgoCD (`sync-wave: 8`, one of the last apps to deploy).
- **Namespace**: `neuvector`
- **Components**:
  - **Controller** (1 replica): Central brain for policy management, learning, and API.
  - **Enforcer** (DaemonSet): Runs on every node including control-plane nodes (tolerates `node-role.kubernetes.io/control-plane:NoSchedule`). Monitors and enforces network/process policies.
  - **Manager**: Web UI exposed at `neuvector.homelab.local` via ingress-nginx with TLS from `homelab-ca-issuer`.
  - **Scanner** (1 replica): Performs vulnerability scans on running containers and registry images.
- **Container runtime**: Configured for containerd at `/run/k3s/containerd/containerd.sock` (RKE2 path).
- **Retry policy**: Up to 3 retries with exponential backoff.

## Best Practices

### Security
- Change the default admin password immediately after first deployment (default: `admin/admin`).
- Start in **Discover** mode to let NeuVector learn normal network and process behavior, then switch to **Monitor** and eventually **Protect** mode.
- Integrate with the container registry (Harbor) for pre-deployment vulnerability scanning.
- Configure admission control rules to block deployment of images with critical vulnerabilities.
- Export security events to a SIEM or logging platform for audit trails.

### Performance
- The controller is resource-intensive (2Gi memory request, 4Gi limit) due to policy evaluation and network flow analysis. Monitor actual usage.
- Enforcer resource usage (100m/256Mi request) scales with network traffic volume on each node. Increase limits on busy nodes if needed.
- Scanner resource allocation (200m/512Mi request, 1 CPU/1Gi limit) is adequate for moderate scanning workloads. Queue depth increases with many concurrent scans.
- Avoid running full cluster scans during peak traffic periods.

### Reliability
- A single controller replica is a single point of failure. For production, increase to 3 replicas for HA with leader election.
- Enforcer DaemonSet with control-plane tolerations ensures all node traffic is monitored.
- The containerd socket path (`/run/k3s/containerd/containerd.sock`) is specific to RKE2/k3s. Verify this path if the cluster runtime changes.
- ArgoCD `selfHeal: true` ensures configuration drift is corrected automatically.

## Configuration Reference

### ArgoCD Application (`neuvector.yaml`)

| Setting | Value | Purpose |
|---|---|---|
| `chart` | `core` | NeuVector core chart |
| `targetRevision` | `2.7.*` | Pin to 2.7.x |
| `namespace` | `neuvector` | Dedicated namespace |
| `sync-wave` | `8` | Deploy last |
| `retry.limit` | `3` | Retry on failure |

### Key Values (`neuvector-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `controller.replicas` | `1` | Single controller |
| `controller.resources.requests.memory` | `2Gi` | Memory request |
| `controller.resources.limits.memory` | `4Gi` | Memory limit |
| `enforcer.tolerations` | control-plane NoSchedule | Run on all nodes |
| `enforcer.resources.requests.cpu` | `100m` | CPU request |
| `manager.ingress.enabled` | `true` | Expose web UI |
| `manager.ingress.host` | `neuvector.homelab.local` | External hostname |
| `manager.ingress.tls` | `true` | TLS via cert-manager |
| `scanner.replicas` | `1` | Single scanner |
| `scanner.resources.limits.memory` | `1Gi` | Scanner memory limit |
| `containerd.enabled` | `true` | Use containerd runtime |
| `containerd.path` | `/run/k3s/containerd/containerd.sock` | RKE2 socket path |

## Common Operations and Troubleshooting

| Task | Command |
|---|---|
| Check all pods | `kubectl get pods -n neuvector` |
| View controller logs | `kubectl logs -n neuvector -l app=neuvector-controller-pod` |
| View enforcer logs | `kubectl logs -n neuvector -l app=neuvector-enforcer-pod` |
| Access web console | Browse to `https://neuvector.homelab.local` |
| Check enforcer DaemonSet | `kubectl get ds -n neuvector` |
| View scanner status | `kubectl logs -n neuvector -l app=neuvector-scanner-pod` |
| Force ArgoCD re-sync | `argocd app sync neuvector` |

**Common issues:**
- **Enforcer pods CrashLoopBackOff**: Verify the containerd socket path is correct. On RKE2, it must be `/run/k3s/containerd/containerd.sock`.
- **Manager UI inaccessible**: Check ingress, TLS certificate status, and manager pod health.
- **High controller memory**: Normal during initial discovery phase when learning network flows. Memory usage stabilizes after learning completes.
- **Scanner fails to pull images**: Ensure the scanner can reach the container registry and has proper credentials configured.
- **Network policies blocking traffic**: If NeuVector is in Protect mode, review the learned rules before enforcement. Overly restrictive rules can break application communication.

## Official Documentation

- NeuVector docs: <https://open-docs.neuvector.com/>
- Helm chart: <https://github.com/neuvector/neuvector-helm>
- Runtime security: <https://open-docs.neuvector.com/policy/overview>
- Admission control: <https://open-docs.neuvector.com/policy/admission>
