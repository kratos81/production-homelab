# Tetragon - eBPF Runtime Security

## Overview

Tetragon is an eBPF-based security observability and runtime enforcement tool created by the Cilium project. It operates at the Linux kernel level to provide real-time visibility into process execution, file access, and network activity without requiring application changes or sidecar containers. On this platform, Tetragon extends the existing Cilium CNI foundation to add deep runtime security monitoring across all cluster nodes.

## Architecture on This Platform

- **Deployment model**: Helm chart deployed via ArgoCD (sync-wave 4).
- **Namespace**: `kube-system` (DaemonSet runs on all 5 nodes).
- **Components**:
  - **Tetragon Agent** (DaemonSet, 2 containers per pod): Loads eBPF programs into the kernel to monitor syscalls, process lifecycle, file access, and network connections.
  - **Tetragon Operator** (1 replica): Manages CRDs and coordinates policy distribution across nodes.
- **Metrics**: Prometheus ServiceMonitor enabled with label `release: prometheus`.
- **Log Pipeline**: Security events are written to stdout and collected by Grafana Alloy, then shipped to Loki.

## Capabilities

| Capability | Description |
|---|---|
| **Process Observability** | Track process execution, arguments, credentials (uid/gid), and namespace context |
| **File Integrity Monitoring** | Detect reads/writes to sensitive files (e.g., `/etc/shadow`, `/etc/passwd`, kubelet credentials) |
| **Network Enforcement** | Monitor and enforce network connections at the kernel level, complementing Cilium network policies |
| **Credential Tracking** | `enableProcessCred: true` tracks privilege escalation and credential changes |
| **Namespace Awareness** | `enableProcessNs: true` tracks container namespace context for every event |

## Best Practices

### Security
- Define TracingPolicy CRDs to monitor specific security-sensitive operations (e.g., `execve` of shells in production containers, writes to `/etc` directories).
- Combine Tetragon kernel-level enforcement with NeuVector container-level policies for defense in depth.
- Export events to a SIEM or log aggregation system (Loki on this platform) for forensic analysis.

### Performance
- Tetragon's eBPF programs run in kernel space with minimal overhead (typically < 1% CPU impact).
- Resource limits are set to 500m CPU / 512Mi memory per node. Monitor if processing high-volume events.
- Use targeted TracingPolicies rather than broad wildcards to minimize event volume.

### Reliability
- Tetragon runs as a DaemonSet -- if a node's Tetragon pod crashes, that node loses runtime visibility until the pod restarts.
- The operator manages CRD lifecycle -- ensure it is healthy before deploying new TracingPolicies.
- eBPF programs survive pod restarts but are reloaded on node reboot.

## Configuration Reference

### Values (`tetragon-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `tetragon.enabled` | `true` | Enable Tetragon agent |
| `tetragon.enableProcessCred` | `true` | Track process credentials (uid/gid changes) |
| `tetragon.enableProcessNs` | `true` | Track process namespace context |
| `tetragonOperator.enabled` | `true` | Deploy the Tetragon operator |
| `tetragonOperator.prometheus.serviceMonitor.enabled` | `true` | Prometheus metrics collection |
| `export.stdout.enabledCommand` | `true` | Include command in event logs |
| `export.stdout.enabledArgs` | `true` | Include command arguments in event logs |

## Useful Commands

| Task | Command |
|---|---|
| View Tetragon pods | `kubectl get pods -n kube-system -l app.kubernetes.io/name=tetragon` |
| Stream security events | `kubectl logs -n kube-system -l app.kubernetes.io/name=tetragon -f` |
| List TracingPolicies | `kubectl get tracingpolicies` |
| View events in Grafana/Loki | Query: `{namespace="kube-system", pod=~"tetragon.*"}` |
| Check Tetragon metrics | `kubectl port-forward -n kube-system ds/tetragon 2112:2112` then `curl localhost:2112/metrics` |

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Tetragon pods in CrashLoopBackOff | Kernel version incompatibility | Check `uname -r` on nodes; requires kernel >= 4.19 (5.x recommended) |
| No events in logs | eBPF programs not loaded | Check `kubectl logs` for BTF (BPF Type Format) errors; ensure kernel has BTF enabled |
| High memory usage | Broad TracingPolicy generating too many events | Narrow TracingPolicy selectors or increase memory limits |
| Operator not syncing policies | CRD not installed | Ensure `tracingpolicies.cilium.io` CRD exists |

## Related Components

- **Cilium** -- Tetragon extends Cilium's eBPF foundation; both share the kernel-level eBPF infrastructure.
- **Grafana Alloy** -- Collects Tetragon stdout events and ships to Loki.
- **Loki** -- Stores and indexes Tetragon security events for querying in Grafana.
- **NeuVector** -- Provides complementary container-level runtime security (process profiles, network firewalling).
- **Prometheus** -- Collects Tetragon operator metrics via ServiceMonitor.
