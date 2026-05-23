# K8sGPT Operator

## Overview

K8sGPT is an AI-powered Kubernetes diagnostics tool that scans clusters for issues and explains them in plain language using LLM backends. The K8sGPT Operator manages K8sGPT instances declaratively via a Custom Resource (CR), enabling GitOps-driven AI diagnostics.

## Architecture on This Platform

- **Cluster**: RKE2 Kubernetes on VMware vSphere / vCenter
- **Deployment**: Two-part ArgoCD GitOps setup:
  - Operator Helm chart with values from `application/values/k8sgpt-values.yaml`
  - K8sGPT Custom Resource from `application/values/k8sgpt-config/k8sgpt-cr.yaml`
- **Namespace**: `k8sgpt`
- **LLM backend**: Ollama via LocalAI-compatible API at `http://ollama.ai-platform.svc.cluster.local:11434/v1`, model `llama3.2:3b`
- **Caching**: Enabled (`noCache: false`) to avoid redundant LLM calls for known issues
- **Integrations**: Trivy (disabled), Backstage (disabled)
- **Monitoring**: ServiceMonitor and Grafana dashboard enabled

## Best Practices

### Security
- The K8sGPT analyzer needs broad read access to cluster resources. Review the operator's ClusterRole and restrict if needed.
- LLM traffic stays in-cluster via Ollama; no data leaves the cluster boundary.
- If enabling Trivy integration, ensure Trivy has its own RBAC and is not granted write permissions.

### Performance
- Caching (`noCache: false`) prevents repeated analysis of the same issue, reducing Ollama load.
- The operator itself is lightweight (100m/128Mi); the K8sGPT analyzer pod managed by the CR may need more resources for large clusters.
- Consider scheduling scans at intervals rather than continuous scanning if the cluster has many resources.

### Reliability
- Pin the K8sGPT image version (`v0.3.41`) for reproducible behavior across deployments.
- Monitor the operator and analyzer pod health via the enabled ServiceMonitor.
- If Ollama is unavailable, K8sGPT will queue analyses but not crash. Results will be delayed until the backend recovers.

## Configuration Reference

### Operator Values (`k8sgpt-values.yaml`)

| Key | Current Value | Purpose |
|-----|---------------|---------|
| `serviceMonitor.enabled` | `true` | Prometheus scraping |
| `grafanaDashboard.enabled` | `true` | Auto-provision Grafana dashboard |
| `resources.requests` | `100m / 128Mi` | Operator CPU/memory requests |
| `resources.limits` | `500m / 512Mi` | Operator CPU/memory limits |

### K8sGPT Custom Resource (`k8sgpt-cr.yaml`)

| Key | Current Value | Purpose |
|-----|---------------|---------|
| `spec.ai.enabled` | `true` | Enable AI-powered analysis |
| `spec.ai.model` | `llama3.2:3b` | LLM model name |
| `spec.ai.backend` | `localai` | Backend type (Ollama via LocalAI API) |
| `spec.ai.baseUrl` | `http://ollama....:11434/v1` | LLM API endpoint |
| `spec.noCache` | `false` | Cache analysis results |
| `spec.version` | `v0.3.41` | K8sGPT analyzer image version |
| `spec.integrations.trivy.enabled` | `false` | Vulnerability scanning disabled |

## Common Operations and Troubleshooting

- **View analysis results**: `kubectl get results -n k8sgpt` to see detected issues and AI explanations.
- **Force re-analysis**: Delete cached results with `kubectl delete results --all -n k8sgpt`.
- **Change LLM model**: Update `spec.ai.model` in the CR and ensure the model is available in Ollama.
- **Operator not reconciling**: Check operator logs: `kubectl logs -l app.kubernetes.io/name=k8sgpt-operator -n k8sgpt`.
- **No results appearing**: Verify the K8sGPT analyzer pod is running: `kubectl get pods -n k8sgpt`. Check that the Ollama endpoint is reachable from the namespace.
- **Enable Trivy scanning**: Set `spec.integrations.trivy.enabled: true` and deploy Trivy in the cluster.

## Official Documentation

- K8sGPT: https://k8sgpt.ai/
- K8sGPT Operator: https://github.com/k8sgpt-ai/k8sgpt-operator
- K8sGPT Docs: https://docs.k8sgpt.ai/
