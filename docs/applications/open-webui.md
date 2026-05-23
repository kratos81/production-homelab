# Open WebUI - LLM Chat Interface

## Overview

Open WebUI provides a web-based chat interface for interacting with LLM models served by Ollama. It offers a user-friendly experience similar to ChatGPT, with conversation history, model selection, and document upload capabilities.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on Harvester HCI
- **Namespace**: `ai-platform`
- **Endpoint**: `https://chat.homelab.local` via NGINX ingress with TLS
- **Ollama Backend**: `http://ollama.ai-platform.svc.cluster.local:11434` (embedded Ollama disabled)
- **Storage**: 5Gi persistent volume for conversation data and uploaded documents
- **Deployment**: Managed via ArgoCD Application with sync wave `14`
- **Helm Chart**: `open-webui` from `https://helm.openwebui.com/` (version `6.*`)
- **Sync Policy**: Automated with self-heal, prune, and retry (5 attempts, exponential backoff)

## Best Practices

### Security
- Open WebUI has built-in user authentication; configure an admin account on first launch
- For SSO, configure OIDC settings to integrate with Keycloak (`https://keycloak.homelab.local/realms/homelab`)
- The ingress allows unlimited body size (`proxy-body-size: "0"`) for document uploads; consider setting a reasonable limit if abuse is a concern
- Restrict ingress access with network policies if the UI should only be available internally

### Performance
- Resource limits (1 CPU / 2Gi) are suitable for moderate concurrent users (~10-20)
- Long inference requests are accommodated by 600s proxy timeouts
- If response latency is high, the bottleneck is likely Ollama, not Open WebUI
- Scale `replicaCount` for higher concurrent user loads

### Reliability
- Persistent storage preserves conversation history across pod restarts
- The ArgoCD Application uses retry with exponential backoff (60s base, 10m max, 5 attempts)
- Monitor pod health via readiness/liveness probes configured in the Helm chart defaults

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `replicaCount` | `1` | Number of Open WebUI replicas |
| `ollama.enabled` | `false` | Embedded Ollama disabled |
| `ollamaUrls[0]` | `http://ollama.ai-platform.svc.cluster.local:11434` | External Ollama endpoint |
| `persistence.size` | `5Gi` | Data storage volume |
| `resources.limits` | 1 CPU / 2Gi | Pod resource limits |
| `ingress.host` | `chat.homelab.local` | External hostname |
| `ingress: proxy-read-timeout` | `600` | Timeout for LLM responses |

## Common Operations and Troubleshooting

```bash
# Check pod status
kubectl -n ai-platform get pods -l app.kubernetes.io/name=open-webui

# View application logs
kubectl -n ai-platform logs -l app.kubernetes.io/name=open-webui -f

# Verify Ollama connectivity from Open WebUI pod
kubectl -n ai-platform exec -it deploy/open-webui -- \
  curl -s http://ollama.ai-platform.svc.cluster.local:11434/api/tags

# Check ArgoCD sync status
kubectl -n argocd get application open-webui

# Force ArgoCD resync
argocd app sync open-webui

# Check persistent volume usage
kubectl -n ai-platform exec -it deploy/open-webui -- df -h /app/backend/data
```

## Official Documentation

- Open WebUI Docs: https://docs.openwebui.com/
- Open WebUI Helm Chart: https://github.com/open-webui/helm-charts
- Open WebUI GitHub: https://github.com/open-webui/open-webui
