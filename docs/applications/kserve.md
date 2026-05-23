# KServe - Model Serving Platform

## Overview

KServe provides a standardized model serving interface on Kubernetes, supporting multiple ML frameworks (TensorFlow, PyTorch, scikit-learn, XGBoost, and custom containers). It enables auto-scaling, canary rollouts, and inference graph composition for deploying ML models from the MLflow registry.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on VMware vSphere / vCenter
- **Namespace**: `kserve` (controller); inference services deploy to application namespaces
- **Mode**: Serverless or RawDeployment (depending on Knative/Istio availability)
- **Model Storage**: MinIO S3 bucket `models` for model artifacts
- **Integration**: Models tracked in MLflow, served via KServe InferenceService CRDs

## Best Practices

### Security
- Use Kubernetes ServiceAccounts with MinIO credentials for each InferenceService to access model artifacts
- Apply network policies to restrict inference endpoint access to authorized namespaces
- Enable TLS on inference endpoints via ingress annotations or Istio/Knative gateway configuration
- Use RBAC to control who can create or modify InferenceService resources

### Performance
- Set appropriate resource requests/limits per InferenceService based on model size and expected QPS
- The controller is lightweight (500m CPU / 512Mi limits); it manages CRDs and does not handle inference traffic
- Use `minReplicas: 0` with scale-to-zero for infrequently used models to conserve cluster resources
- For GPU models, specify `nvidia.com/gpu` in the InferenceService predictor resources
- Enable request batching for high-throughput inference workloads

### Reliability
- Use canary rollouts (`canaryTrafficPercent`) when updating model versions
- Configure `minReplicas: 1` for critical models to avoid cold-start latency
- Set up readiness probes and model health checks in InferenceService specs
- Monitor inference latency and error rates via Prometheus metrics

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `kserve.controller.resources.requests` | 100m CPU / 256Mi | Controller guaranteed resources |
| `kserve.controller.resources.limits` | 500m CPU / 512Mi | Controller maximum resources |

### Example InferenceService

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: my-model
  namespace: ai-platform
spec:
  predictor:
    model:
      modelFormat:
        name: mlflow
      storageUri: s3://models/my-model/1
      resources:
        requests:
          cpu: 500m
          memory: 1Gi
        limits:
          cpu: 2
          memory: 4Gi
```

## Common Operations and Troubleshooting

```bash
# Check KServe controller status
kubectl -n kserve get pods

# List all InferenceServices
kubectl get inferenceservices --all-namespaces

# Check InferenceService status
kubectl -n ai-platform get inferenceservice <name> -o yaml

# View predictor pod logs
kubectl -n ai-platform logs -l serving.kserve.io/inferenceservice=<name>

# Test inference endpoint
curl -s -H "Content-Type: application/json" \
  -d '{"instances": [[1.0, 2.0, 3.0]]}' \
  https://<inference-host>/v1/models/<name>:predict

# Check controller logs for reconciliation errors
kubectl -n kserve logs -l control-plane=kserve-controller-manager

# Verify S3 model access
kubectl -n ai-platform exec -it deploy/kserve-controller-manager -- \
  curl -s http://minio.minio.svc.cluster.local:9000/minio/health/live
```

## Official Documentation

- KServe Docs: https://kserve.github.io/website/
- KServe InferenceService API: https://kserve.github.io/website/master/reference/api/
- KServe MLflow Integration: https://kserve.github.io/website/master/modelserving/v1beta1/mlflow/v2/
- KServe on Kubernetes without Istio: https://kserve.github.io/website/master/admin/kubernetes_deployment/
