# HolmesGPT AI Troubleshooting

## Overview

HolmesGPT is an AI-powered Kubernetes troubleshooting assistant that analyzes cluster issues using LLM reasoning. It integrates with Prometheus, Alertmanager, Grafana, and Kubernetes APIs to investigate alerts, diagnose problems, and suggest remediations. On this platform, it uses a local Ollama-hosted LLM for privacy and cost efficiency.

## Architecture on This Platform

- **Cluster**: RKE2 Kubernetes on Proxmox VE
- **Deployment**: Managed via ArgoCD GitOps from `application/values/holmesgpt-values.yaml`
- **LLM backend**: Ollama running in the `ai-platform` namespace, model `llama3.2:3b` with low temperature (0.1) for deterministic outputs
- **Toolsets enabled**: Kubernetes logs, Kubernetes resources, Prometheus queries, Grafana queries
- **Integrations**: Connects to Prometheus (`monitoring` namespace, port 9090) and Alertmanager (port 9093) for alert-driven investigation

## Best Practices

### Security
- HolmesGPT has read access to Kubernetes resources and logs cluster-wide. Scope its ServiceAccount RBAC to only necessary namespaces if full cluster access is not desired.
- The Ollama endpoint is internal (`ai-platform.svc.cluster.local`); do not expose it externally.
- Audit HolmesGPT queries if the LLM backend changes to a cloud-hosted model to prevent sensitive data leakage.

### Performance
- The `llama3.2:3b` model is lightweight but may produce less accurate analysis than larger models. Consider upgrading to `llama3.2:8b` or higher if GPU resources allow.
- Temperature 0.1 keeps outputs focused; increase slightly (0.3-0.5) if more creative troubleshooting suggestions are needed.
- Resource limits of 1 CPU / 1Gi memory are appropriate for the orchestration layer; the heavy computation happens on the Ollama side.

### Reliability
- Ensure the Ollama service is healthy before relying on HolmesGPT. If Ollama is down, HolmesGPT will fail to produce analysis.
- Monitor HolmesGPT pod health and response times. Slow responses usually indicate Ollama resource contention.
- Keep the model version pinned to avoid unexpected behavior changes from model updates.

## Configuration Reference

| Key | Current Value | Purpose |
|-----|---------------|---------|
| `additionalEnvVars[].OLLAMA_BASE_URL` | `http://ollama.ai-platform.svc:11434` | Ollama LLM endpoint |
| `modelList[0].name` | `llama3.2:3b` | LLM model for analysis |
| `modelList[0].temperature` | `0.1` | Response determinism |
| `toolsets.kubernetes/logs` | `true` | Enable log analysis |
| `toolsets.kubernetes/resources` | `true` | Enable resource inspection |
| `toolsets.prometheus/query` | `true` | Enable PromQL queries |
| `toolsets.grafana/query` | `true` | Enable Grafana queries |
| `prometheusUrl` | `...:9090` | Prometheus service URL |
| `alertmanagerUrl` | `...:9093` | Alertmanager service URL |
| `resources.requests` | `250m / 512Mi` | CPU/memory requests |
| `resources.limits` | `1 / 1Gi` | CPU/memory limits |

## Common Operations and Troubleshooting

- **Trigger an investigation**: HolmesGPT reacts to Prometheus alerts or can be queried directly for cluster issues.
- **Change LLM model**: Update `modelList[0].name` and ensure the model is pulled in Ollama (`ollama pull <model>`).
- **Slow responses**: Check Ollama pod resource usage; the 3b model should respond in seconds on adequate hardware.
- **Empty or unhelpful analysis**: Verify toolset connectivity -- check that Prometheus and Alertmanager URLs resolve and return data.
- **Pod failing to start**: Check for RBAC errors in pod logs; HolmesGPT needs cluster-reader permissions.

## Official Documentation

- HolmesGPT: https://github.com/robusta-dev/holmesgpt
- Ollama: https://ollama.ai/
- Robusta (parent project): https://docs.robusta.dev/
