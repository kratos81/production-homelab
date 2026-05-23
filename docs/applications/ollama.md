# Ollama - LLM Inference Server

## Overview

Ollama provides local LLM inference capabilities for the platform. It hosts multiple language models for code generation, general-purpose chat, and text embeddings, serving as the backend for Open WebUI and available to JupyterHub notebooks.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on Harvester HCI
- **Namespace**: `ai-platform`
- **Endpoint**: `https://ollama.homelab.local` via NGINX ingress with TLS
- **Internal Service**: `http://ollama.ai-platform.svc.cluster.local:11434`
- **Storage**: 30Gi persistent volume for model files
- **Models**: `llama3.2:3b`, `codellama:7b`, `nomic-embed-text`
- **Proxy Configuration**: Unlimited body size, 600s read/send timeouts for large model interactions

## Best Practices

### Security
- Ollama does not have built-in authentication; restrict access via network policies or ingress auth annotations
- If exposing externally, add `nginx.ingress.kubernetes.io/auth-url` for authentication proxy
- Limit which models can be pulled by configuring allowed model lists

### Performance
- Current resources (4 CPU / 16Gi memory) support CPU-only inference; for GPU acceleration, add `nvidia.com/gpu` resource requests and ensure GPU operator is installed
- The `codellama:7b` model requires approximately 4-7GB RAM during inference; avoid running multiple large models simultaneously on CPU
- `nomic-embed-text` is lightweight and suitable for embedding workloads alongside larger models
- Increase `proxy-read-timeout` beyond 600s if users experience timeouts on complex prompts

### Reliability
- The 30Gi persistent volume stores downloaded models; ensure sufficient space when adding larger models (13B+ parameter models need 8-15GB each)
- Models are pulled on startup via the `ollama.models.pull` list; initial deployment may take significant time
- Monitor pod restarts -- OOMKilled events indicate memory limits need increasing for the loaded model set

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `replicaCount` | `1` | Number of Ollama instances |
| `ollama.models.pull` | `llama3.2:3b, codellama:7b, nomic-embed-text` | Models to download on startup |
| `resources.requests` | 2 CPU / 8Gi | Guaranteed resources |
| `resources.limits` | 4 CPU / 16Gi | Maximum resources |
| `persistentVolume.size` | `30Gi` | Model storage volume |
| `service.port` | `11434` | API port |
| `ingress.hosts[0].host` | `ollama.homelab.local` | External hostname |
| `ingress: proxy-read-timeout` | `600` | Timeout for long inference requests |

## Common Operations and Troubleshooting

```bash
# Check Ollama pod status
kubectl -n ai-platform get pods -l app.kubernetes.io/name=ollama

# View model download progress during startup
kubectl -n ai-platform logs -l app.kubernetes.io/name=ollama -f

# List loaded models
curl -s https://ollama.homelab.local/api/tags | jq '.models[].name'

# Test inference
curl -s https://ollama.homelab.local/api/generate -d '{"model":"llama3.2:3b","prompt":"Hello","stream":false}' | jq '.response'

# Pull a new model
curl -s https://ollama.homelab.local/api/pull -d '{"name":"mistral:7b"}'

# Check model storage usage
kubectl -n ai-platform exec -it deploy/ollama -- du -sh /root/.ollama/models

# Monitor memory usage (critical for OOM prevention)
kubectl -n ai-platform top pod -l app.kubernetes.io/name=ollama
```

## Official Documentation

- Ollama Docs: https://github.com/ollama/ollama/blob/main/docs/README.md
- Ollama API Reference: https://github.com/ollama/ollama/blob/main/docs/api.md
- Ollama Helm Chart: https://github.com/otwld/ollama-helm
- Ollama Model Library: https://ollama.com/library
