# Loki Log Aggregation

## Overview

Grafana Loki is a horizontally scalable, highly available log aggregation system inspired by Prometheus. It indexes metadata (labels) rather than full log content, making it cost-effective and performant. Loki serves as the centralized logging backend for the platform.

## Architecture on This Platform

- **Cluster**: RKE2 Kubernetes on VMware vSphere / vCenter
- **Deployment**: Managed via ArgoCD GitOps from `application/values/loki-values.yaml`
- **Mode**: Single-binary (monolithic) deployment with persistence enabled
- **Log ingestion**: Grafana Alloy (DaemonSet) replaces Promtail as the log collector (`promtail.enabled: false`)
- **Retention**: 7 days (168h) with automatic deletion of expired chunks
- **Authentication**: Disabled (`auth_enabled: false`) -- single-tenant mode
- **Integration**: Registered as a data source in Grafana, with trace-to-log correlation from Tempo

## Best Practices

### Security
- Since `auth_enabled` is false, Loki accepts writes from any source in the cluster. Restrict access using NetworkPolicies to allow only Alloy and Grafana.
- Do not expose Loki externally; keep it as a ClusterIP service.
- Consider enabling auth if multi-tenant log isolation is needed.

### Performance
- The 20Gi PVC must accommodate 7 days of logs; monitor `loki_ingester_memory_chunks` and disk usage.
- Tune `max_look_back_period` to match retention to prevent queries against non-existent data.
- Use structured logging (JSON) in applications for efficient label extraction by Alloy.
- Avoid high-cardinality labels (e.g., request IDs) as they degrade query performance.

### Reliability
- Enable persistence (already enabled) to survive pod restarts without data loss.
- Monitor Loki health via the ServiceMonitor scraped by Prometheus and the pre-provisioned Loki Grafana dashboard (gnetId 13639).
- Set resource limits appropriately; the 1Gi memory limit may need increase for clusters with heavy log volume.

## Configuration Reference

| Key | Current Value | Purpose |
|-----|---------------|---------|
| `loki.enabled` | `true` | Enable Loki deployment |
| `loki.persistence.enabled` | `true` | Persistent storage for chunks |
| `loki.persistence.size` | `20Gi` | PVC size |
| `loki.config.auth_enabled` | `false` | Single-tenant mode |
| `loki.config.chunk_store_config.max_look_back_period` | `168h` | Max query lookback |
| `loki.config.table_manager.retention_period` | `168h` | Data retention (7 days) |
| `loki.resources.requests` | `250m / 256Mi` | CPU/memory requests |
| `loki.resources.limits` | `1 / 1Gi` | CPU/memory limits |
| `promtail.enabled` | `false` | Promtail disabled (Alloy used instead) |

## Common Operations and Troubleshooting

- **Query logs**: Use Grafana Explore with the Loki data source. Use LogQL: `{namespace="default"} |= "error"`.
- **Check ingestion rate**: Query `sum(rate(loki_distributor_bytes_received_total[5m]))` in Prometheus.
- **Loki OOM**: Increase memory limits or reduce concurrent queries via `query_scheduler` settings.
- **Missing logs**: Verify Alloy DaemonSet pods are running on all nodes and forwarding to the correct Loki endpoint.
- **Slow queries**: Add label filters before line filters in LogQL; avoid `{job=~".+"}` without specific labels.

## Official Documentation

- Loki: https://grafana.com/docs/loki/latest/
- LogQL: https://grafana.com/docs/loki/latest/logql/
- Loki Helm chart: https://github.com/grafana/helm-charts/tree/main/charts/loki
