# ingress-nginx - Ingress Controller

## Overview

ingress-nginx is the default ingress controller for this platform. It processes Kubernetes Ingress resources and routes external HTTP/HTTPS traffic to backend services. It runs as the default IngressClass and receives its external IP from MetalLB via a `LoadBalancer`-type Service.

## Architecture on This Platform

- **Deployment model**: Helm chart deployed via ArgoCD, configured as the cluster's default ingress class (`nginx`).
- **Service type**: `LoadBalancer` -- MetalLB assigns an external IP from the configured pool.
- **TLS termination**: TLS is terminated at the ingress controller using certificates issued by cert-manager's `homelab-ca-issuer`.
- **Metrics**: Prometheus metrics enabled with a ServiceMonitor labeled `release: prometheus`.
- **Consumers**: Vault, Harbor, Keycloak, NeuVector, and all other HTTP-exposed workloads.

## Best Practices

### Security
- Keep the controller image up to date to patch known CVEs in the nginx/OpenResty stack.
- Use `NetworkPolicy` to restrict traffic to the ingress controller namespace.
- Set appropriate annotations on Ingress resources for rate limiting, request size limits, and header security.
- Enable ModSecurity WAF via annotations for internet-facing workloads if applicable.

### Performance
- Resource requests (200m CPU, 256Mi memory) and limits (500m CPU, 512Mi memory) are tuned for moderate traffic. Scale horizontally with `replicaCount` for higher throughput.
- Tune `proxy-body-size`, `proxy-read-timeout`, and `proxy-buffer-size` per-Ingress via annotations for workloads with specific needs (e.g., Harbor uses `proxy-body-size: "0"` for unlimited image push size).
- Enable gzip compression via ConfigMap for text-heavy responses.

### Reliability
- Run multiple replicas with pod anti-affinity for high availability.
- Use `PodDisruptionBudget` to prevent all replicas from being evicted simultaneously during node maintenance.
- Monitor the ServiceMonitor metrics for 5xx error rates and latency spikes.

## Configuration Reference

### Values (`ingress-nginx-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `controller.service.type` | `LoadBalancer` | Get IP from MetalLB |
| `controller.ingressClassResource.name` | `nginx` | IngressClass name |
| `controller.ingressClassResource.default` | `true` | Default IngressClass |
| `controller.resources.requests.cpu` | `200m` | CPU request |
| `controller.resources.requests.memory` | `256Mi` | Memory request |
| `controller.resources.limits.cpu` | `500m` | CPU limit |
| `controller.resources.limits.memory` | `512Mi` | Memory limit |
| `controller.metrics.enabled` | `true` | Expose Prometheus metrics |
| `controller.metrics.serviceMonitor.enabled` | `true` | Create ServiceMonitor |

## Common Operations and Troubleshooting

| Task | Command |
|---|---|
| Check controller pods | `kubectl get pods -n ingress-nginx` |
| View controller logs | `kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx` |
| List all Ingress resources | `kubectl get ingress -A` |
| Check external IP | `kubectl get svc -n ingress-nginx` |
| Test backend connectivity | `kubectl exec -n ingress-nginx <pod> -- curl -k https://localhost/healthz` |
| View nginx config | `kubectl exec -n ingress-nginx <pod> -- cat /etc/nginx/nginx.conf` |
| Force ArgoCD re-sync | `argocd app sync ingress-nginx` |

**Common issues:**
- **Service stuck in `<pending>`**: MetalLB is not running or IP pool is exhausted. Check MetalLB speaker pods and `IPAddressPool`.
- **502 Bad Gateway**: Backend pods are not ready or Service selector does not match. Check endpoints with `kubectl get endpoints`.
- **413 Entity Too Large**: Increase `nginx.ingress.kubernetes.io/proxy-body-size` annotation on the relevant Ingress.
- **SSL certificate errors**: Verify the cert-manager Certificate is in `Ready` state and the TLS secret exists in the Ingress namespace.

## Official Documentation

- ingress-nginx docs: <https://kubernetes.github.io/ingress-nginx/>
- Annotations reference: <https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/>
- Helm chart: <https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx>
