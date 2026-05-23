# OpenCost FinOps

## Overview

OpenCost is a CNCF project that provides real-time Kubernetes cost monitoring. It allocates infrastructure costs to namespaces, deployments, pods, and labels based on actual resource consumption. On this platform, OpenCost uses custom pricing to reflect the true cost of the VMware vSphere / vCenter infrastructure.

## Architecture on This Platform

- **Cluster**: RKE2 Kubernetes on VMware vSphere / vCenter, cluster ID `rke2-cluster-02`
- **Deployment**: Managed via ArgoCD GitOps from `application/values/opencost-values.yaml`
- **Prometheus integration**: Uses the internal Prometheus instance (`prometheus-kube-prometheus-prometheus` in `monitoring` namespace, port 9090)
- **UI**: Enabled with Ingress at `opencost.homelab.local`, TLS via cert-manager (`homelab-ca-issuer`)
- **Exporter**: Reports cost allocation metrics to Prometheus
- **Custom pricing**: Enabled with on-premises cost model (no cloud billing API)

## Best Practices

### Security
- The UI is exposed via Ingress with TLS. Add authentication (e.g., OAuth2 proxy or Keycloak) to prevent unauthorized access to cost data.
- The exporter needs read access to Prometheus; ensure its ServiceAccount is scoped appropriately.
- Cost data can reveal organizational priorities; restrict dashboard access to authorized personnel.

### Performance
- The exporter and UI are lightweight (50m/64Mi requests each). These rarely need adjustment.
- OpenCost queries Prometheus for resource metrics; ensure Prometheus has sufficient resources for additional query load.
- Custom pricing eliminates the need for cloud API calls, reducing latency.

### Reliability
- Accurate cost data depends on healthy Prometheus metrics. If Prometheus is down, OpenCost will show stale data.
- Monitor via the ServiceMonitor (labeled `release: prometheus`) to track exporter health.
- Periodically validate custom pricing rates against actual infrastructure costs.

## Configuration Reference

| Key | Current Value | Purpose |
|-----|---------------|---------|
| `opencost.prometheus.internal.enabled` | `true` | Use in-cluster Prometheus |
| `opencost.prometheus.internal.serviceName` | `prometheus-kube-prometheus-prometheus` | Prometheus service |
| `opencost.prometheus.internal.namespaceName` | `monitoring` | Prometheus namespace |
| `opencost.ui.enabled` | `true` | Enable cost dashboard UI |
| `opencost.ui.ingress.hosts[0].host` | `opencost.homelab.local` | UI hostname |
| `opencost.exporter.defaultClusterId` | `rke2-cluster-02` | Cluster identifier |
| `opencost.customPricing.enabled` | `true` | Use custom cost model |
| `opencost.customPricing.costModel.CPU` | `$0.031611/hr` | On-demand CPU cost per core-hour |
| `opencost.customPricing.costModel.RAM` | `$0.004237/hr` | On-demand RAM cost per GiB-hour |
| `opencost.customPricing.costModel.storage` | `$0.00005479/hr` | Storage cost per GiB-hour |
| `opencost.customPricing.costModel.spotCPU` | `$0.006655/hr` | Spot CPU cost (if applicable) |
| `opencost.customPricing.costModel.spotRAM` | `$0.000892/hr` | Spot RAM cost (if applicable) |
| `serviceMonitor.enabled` | `true` | Prometheus scraping |

## Common Operations and Troubleshooting

- **View costs**: Navigate to `https://opencost.homelab.local` or use the API: `kubectl port-forward svc/opencost 9003:9003`.
- **Update pricing**: Modify `customPricing.costModel` values in the values file and sync via ArgoCD.
- **Query cost API**: `curl http://opencost:9003/allocation/compute?window=1d&aggregate=namespace`.
- **Costs showing $0**: Verify Prometheus is reachable and `container_cpu_usage_seconds_total` / `container_memory_working_set_bytes` metrics exist.
- **Ingress not working**: Check cert-manager for certificate readiness: `kubectl get certificate opencost-tls`.
- **Inaccurate costs**: Review and update custom pricing rates; ensure node-exporter is running on all nodes for accurate capacity data.

## Official Documentation

- OpenCost: https://www.opencost.io/docs/
- OpenCost API: https://www.opencost.io/docs/integrations/api
- OpenCost Helm chart: https://github.com/opencost/opencost-helm-chart
