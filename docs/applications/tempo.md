# Grafana Tempo Distributed Tracing

## Overview

Grafana Tempo is a high-scale distributed tracing backend. It requires only object storage or local disk, does not need indexing, and integrates natively with Grafana for trace visualization. Tempo receives traces via OTLP and provides trace-to-logs and trace-to-metrics correlation.

## Architecture on This Platform

- **Cluster**: RKE2 Kubernetes on Proxmox VE
- **Deployment**: Managed via ArgoCD GitOps from `application/values/tempo-values.yaml`
- **Mode**: Single-binary (monolithic) deployment with local persistent storage
- **Receivers**: OTLP gRPC (port 4317) and OTLP HTTP (port 4318)
- **Retention**: 7 days (168h)
- **Integration**: Grafana data source with trace-to-logs (Loki) and trace-to-metrics (Prometheus) correlation enabled. Service map and node graph are active.
- **Collection**: Grafana Alloy forwards traces from instrumented applications to Tempo via OTLP HTTP

## Best Practices

### Security
- Tempo endpoints are unauthenticated; use NetworkPolicies to restrict ingestion to Alloy only.
- Do not expose OTLP receiver ports outside the cluster without mTLS or an authenticating proxy.
- Bind receivers to `0.0.0.0` only within the pod network; avoid host networking.

### Performance
- The 10Gi PVC is suitable for moderate trace volumes with 7-day retention. Monitor disk usage and scale as needed.
- Use tail-based sampling in Alloy to reduce storage costs while retaining error and high-latency traces.
- Keep span attribute cardinality low; avoid placing unique IDs in span attributes that are indexed.

### Reliability
- Persistence is enabled, preventing trace data loss across pod restarts.
- The ServiceMonitor (labeled `release: prometheus`) ensures Prometheus scrapes Tempo metrics for self-monitoring.
- Monitor `tempo_ingester_traces_created_total` and `tempo_distributor_spans_received_total` for ingestion health.

## Configuration Reference

| Key | Current Value | Purpose |
|-----|---------------|---------|
| `tempo.receivers.otlp.protocols.grpc.endpoint` | `0.0.0.0:4317` | OTLP gRPC receiver |
| `tempo.receivers.otlp.protocols.http.endpoint` | `0.0.0.0:4318` | OTLP HTTP receiver |
| `tempo.retention` | `168h` | Trace retention (7 days) |
| `tempo.resources.requests` | `250m / 512Mi` | CPU/memory requests |
| `tempo.resources.limits` | `1 / 1Gi` | CPU/memory limits |
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.size` | `10Gi` | PVC size |
| `serviceMonitor.enabled` | `true` | Prometheus scraping |
| `serviceMonitor.additionalLabels.release` | `prometheus` | ServiceMonitor selector label |

## Common Operations and Troubleshooting

- **Search traces**: Use Grafana Explore with the Tempo data source. Search by trace ID or use TraceQL.
- **View service map**: Open Grafana Explore, select Tempo, and use the Service Graph tab.
- **No traces appearing**: Verify Alloy is forwarding to `http://tempo.monitoring.svc.cluster.local:4318` and check Alloy logs for export errors.
- **High memory usage**: Reduce `max_bytes_per_trace` or increase limits. Check for applications emitting excessively large traces.
- **Correlate trace to logs**: Click a trace span in Grafana; the trace-to-logs link navigates to Loki filtered by trace ID.

## Official Documentation

- Tempo: https://grafana.com/docs/tempo/latest/
- TraceQL: https://grafana.com/docs/tempo/latest/traceql/
- Tempo Helm chart: https://github.com/grafana/helm-charts/tree/main/charts/tempo
