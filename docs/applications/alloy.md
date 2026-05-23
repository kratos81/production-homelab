# Grafana Alloy Unified Telemetry Collector

## Overview

Grafana Alloy is a vendor-neutral OpenTelemetry Collector distribution that replaces Promtail, Grafana Agent, and standalone OTel collectors. It collects logs, metrics, and traces in a single binary using a declarative River configuration language. On this platform, Alloy serves as the universal telemetry pipeline.

## Architecture on This Platform

- **Cluster**: RKE2 Kubernetes on Harvester HCI
- **Deployment**: Managed via ArgoCD GitOps from `application/values/alloy-values.yaml`
- **Controller type**: DaemonSet (one pod per node for log collection)
- **Pipelines configured**:
  - **Logs**: Kubernetes pod discovery -> relabeling (namespace, pod, container, app) -> Loki push
  - **Traces**: OTLP gRPC/HTTP receiver -> export to Tempo via OTLP HTTP
  - **Metrics**: OTLP receiver -> Prometheus remote_write
- **Endpoints**: OTLP gRPC on port 4317, OTLP HTTP on port 4318 (exposed as extra service ports)
- **Self-monitoring**: ServiceMonitor enabled with `release: prometheus` label, log level `info`

## Best Practices

### Security
- OTLP receiver binds to `0.0.0.0`; restrict access with NetworkPolicies to allow only application namespaces.
- Use TLS for OTLP endpoints if accepting traces from outside the cluster.
- The Loki and Tempo endpoints use `insecure: true` for in-cluster communication, which is acceptable for internal traffic but should not be used across network boundaries.

### Performance
- As a DaemonSet, Alloy competes for node resources. The 100m/128Mi request is lightweight; monitor actual usage and adjust.
- Avoid collecting logs from noisy system namespaces unless needed -- add exclusion rules in `discovery.relabel`.
- For high-throughput clusters, increase the memory limit above 512Mi to prevent OOM during log spikes.
- Use batch processors for OTLP metrics and traces to reduce network overhead.

### Reliability
- DaemonSet ensures coverage on every node. Verify no nodes are missing pods with `kubectl get pods -l app.kubernetes.io/name=alloy -o wide`.
- If Loki or Tempo is temporarily down, Alloy will retry but may drop data. Consider enabling WAL (write-ahead log) for durability.
- Monitor Alloy health via its ServiceMonitor and Prometheus metrics.

## Configuration Reference

| Key | Current Value | Purpose |
|-----|---------------|---------|
| `controller.type` | `daemonset` | One collector per node |
| `alloy.configMap.content` | River config (inline) | Full pipeline configuration |
| `alloy.extraPorts[0]` | `4317 (otlp-grpc)` | OTLP gRPC ingestion |
| `alloy.extraPorts[1]` | `4318 (otlp-http)` | OTLP HTTP ingestion |
| `resources.requests` | `100m / 128Mi` | CPU/memory requests |
| `resources.limits` | `500m / 512Mi` | CPU/memory limits |
| `serviceMonitor.enabled` | `true` | Prometheus scraping |
| Loki endpoint | `loki.monitoring.svc:3100` | Log destination |
| Tempo endpoint | `tempo.monitoring.svc:4318` | Trace destination |
| Prometheus endpoint | `prometheus-kube-prometheus-prometheus.monitoring.svc:9090` | Metrics remote_write destination |

## Common Operations and Troubleshooting

- **Add a label to logs**: Add a `rule` block in `discovery.relabel "pod_logs"` mapping a Kubernetes label to a Loki label.
- **Exclude a namespace from log collection**: Add a drop rule: `rule { source_labels = ["__meta_kubernetes_namespace"]; regex = "kube-system"; action = "drop" }`.
- **Verify OTLP reception**: Send a test trace with `otel-cli` and check Tempo for it.
- **Alloy pod CrashLooping**: Check logs with `kubectl logs -l app.kubernetes.io/name=alloy`; common causes are invalid River config syntax or unreachable endpoints.
- **Missing logs for a pod**: Confirm the pod is on a node where Alloy is running and that the pod's labels match discovery rules.

## Official Documentation

- Grafana Alloy: https://grafana.com/docs/alloy/latest/
- River configuration: https://grafana.com/docs/alloy/latest/concepts/configuration-syntax/
- Alloy Helm chart: https://github.com/grafana/helm-charts/tree/main/charts/alloy
