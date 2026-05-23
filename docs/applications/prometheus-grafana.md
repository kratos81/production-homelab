# kube-prometheus-stack (Prometheus + Grafana)

## Overview

kube-prometheus-stack deploys a full monitoring pipeline: Prometheus for metrics collection and alerting, Grafana for visualization, Alertmanager for alert routing, kube-state-metrics for Kubernetes object metrics, and node-exporter for host-level metrics. This is the core observability component of the platform.

## Architecture on This Platform

- **Cluster**: RKE2 Kubernetes on Proxmox VE
- **Deployment**: Managed via ArgoCD GitOps from `application/values/prometheus-values.yaml`
- **Prometheus** scrapes all ServiceMonitors and PodMonitors cluster-wide (`selectorNilUsesHelmValues: false`)
- **Grafana** is exposed via LoadBalancer with pre-provisioned dashboards for ArgoCD, ingress-nginx, cert-manager, Harbor, MinIO, Vault, Keycloak, JupyterHub, Loki, Litmus Chaos, Argo Workflows, Kyverno, Milvus, MetalLB, NeuVector, OpenCost, Velero, Mattermost, GitLab, Alloy, Tempo, External DNS, Longhorn, KServe, Tailscale, and Open WebUI
- **Data sources** configured: Prometheus (default), Loki (logs), Tempo (traces with trace-to-logs and trace-to-metrics correlation)
- **Retention**: 15 days, backed by a 20Gi persistent volume

## Best Practices

### Security
- **Change the default Grafana admin password** -- the current `adminPassword: admin` is insecure. Use a Kubernetes Secret or Vault-injected secret instead.
- Restrict Grafana LoadBalancer access with firewall rules or switch to Ingress with TLS and authentication.
- Use RBAC-scoped ServiceAccounts for Prometheus to limit namespace access if needed.

### Performance
- Monitor Prometheus memory usage; the 2Gi limit is appropriate for small-to-medium clusters but may need increase as cardinality grows.
- Use recording rules for expensive queries that power dashboards.
- Set `scrape_interval` overrides on high-volume ServiceMonitors to reduce ingestion rate.

### Reliability
- The 20Gi PVC with 15-day retention should be sized together -- monitor disk usage via the Prometheus self-monitoring dashboard.
- Enable Alertmanager persistence for alert state across restarts.
- Use `topologySpreadConstraints` or pod anti-affinity for multi-replica deployments.

## Configuration Reference

| Key | Current Value | Purpose |
|-----|---------------|---------|
| `prometheus.prometheusSpec.retention` | `15d` | How long metrics are kept |
| `prometheus.prometheusSpec.storageSpec...storage` | `20Gi` | Prometheus PVC size |
| `prometheus.prometheusSpec.resources.requests` | `500m / 1Gi` | CPU/memory requests |
| `prometheus.prometheusSpec.resources.limits` | `2 / 2Gi` | CPU/memory limits |
| `prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues` | `false` | Discover all ServiceMonitors |
| `grafana.service.type` | `LoadBalancer` | Grafana service exposure |
| `grafana.additionalDataSources` | Loki, Tempo | Extra Grafana data sources |
| `alertmanager.alertmanagerSpec.resources.requests` | `100m / 128Mi` | Alertmanager resources |

## Common Operations and Troubleshooting

- **Add a dashboard**: For Grafana.net dashboards, add an entry under `grafana.dashboards.platform` with the `gnetId` and revision. For custom dashboards, create a ConfigMap with label `grafana_dashboard: "1"` in `application/values/monitoring-extras/`.
- **Add a ServiceMonitor**: Ensure the monitor has a label matching the Prometheus selector (currently accepts all).
- **Check Prometheus targets**: Visit Prometheus UI at `/targets` or query `up` metric.
- **High memory usage**: Check cardinality with `prometheus_tsdb_symbol_table_size_bytes` and `count({__name__=~".+"})`. Drop high-cardinality labels via metric relabeling.
- **Grafana not loading dashboards**: Verify the sidecar or dashboard provisioner pod logs for JSON parse errors.

## Official Documentation

- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/grafana/latest/
- kube-prometheus-stack Helm chart: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- Alertmanager: https://prometheus.io/docs/alerting/latest/alertmanager/
