# OpenTelemetry Operator - Auto-Instrumentation and Telemetry Collection

## Overview

The OpenTelemetry Operator is a Kubernetes operator that manages OpenTelemetry Collectors and auto-instrumentation of application workloads. It enables zero-code observability by injecting language-specific OpenTelemetry SDK agents into application pods via annotations. On this platform, the operator deploys a centralized OTel Collector that receives traces, metrics, and logs via OTLP and exports them to Tempo (traces), Prometheus (metrics), and Loki (logs).

## Architecture on This Platform

- **Deployment model**: Helm chart (operator) + raw manifests (collector + instrumentation CRDs) via ArgoCD.
- **Sync waves**: 10 (operator), 11 (collector and instrumentation config).
- **Namespace**: `opentelemetry`
- **Components**:
  - **OTel Operator** (1 replica, 2 containers): Manages Collector and Instrumentation CRD lifecycle. Webhook certs via cert-manager.
  - **OTel Collector** (Deployment, 1 replica): Receives OTLP data, processes it (batching, memory limiting, resource enrichment), and exports to backends.
  - **Instrumentation CRDs** (4): Python, Java, Node.js, Go auto-instrumentation configurations.

## Telemetry Pipeline

```
Application Pod (auto-instrumented)
    |
    | OTLP (gRPC :4317 / HTTP :4318)
    v
OTel Collector
    |
    +---> Tempo (traces via OTLP gRPC)
    +---> Prometheus (metrics via remote write, port 8889)
    +---> Loki (logs via OTLP HTTP)
```

### Collector Configuration

| Pipeline | Receivers | Processors | Exporters |
|---|---|---|---|
| **Traces** | OTLP (gRPC + HTTP) | memory_limiter, resource (cluster tag), batch | otlp/tempo |
| **Metrics** | OTLP (gRPC + HTTP) | memory_limiter, resource (cluster tag), batch | prometheus |
| **Logs** | OTLP (gRPC + HTTP) | memory_limiter, resource (cluster tag), batch | otlphttp/loki |

### Sampling

All instrumentation CRDs use `parentbased_traceidratio` sampler at 25% (`0.25`). This means 1 in 4 traces are captured, reducing storage while maintaining representative coverage.

## Auto-Instrumentation Usage

To auto-instrument a pod, add the appropriate annotation to the pod spec (or Deployment/StatefulSet template):

| Language | Annotation |
|---|---|
| Python | `instrumentation.opentelemetry.io/inject-python: "opentelemetry/python-instrumentation"` |
| Java | `instrumentation.opentelemetry.io/inject-java: "opentelemetry/java-instrumentation"` |
| Node.js | `instrumentation.opentelemetry.io/inject-nodejs: "opentelemetry/nodejs-instrumentation"` |
| Go | `instrumentation.opentelemetry.io/inject-go: "opentelemetry/go-instrumentation"` |

The operator will inject an init container that downloads the appropriate SDK agent and configures it to send telemetry to the OTel Collector.

## Best Practices

### Security
- Webhook certificates are managed by cert-manager using `homelab-ca-issuer`.
- OTLP endpoints are internal-only (ClusterIP service) -- no external exposure.
- Use the `resource` processor to tag all telemetry with `cluster: rke2-cluster-02` for multi-cluster disambiguation.

### Performance
- The `memory_limiter` processor prevents the collector from consuming unbounded memory (limit: 400 MiB, spike: 100 MiB).
- Batch processor aggregates 1024 items or 5 seconds, reducing backend write pressure.
- 25% sampling rate balances observability coverage with storage cost. Adjust in Instrumentation CRDs for critical services.
- For high-throughput services, consider deploying a sidecar collector instead of the centralized deployment.

### Reliability
- The collector runs as a single replica. For production-critical telemetry, increase to 2+ replicas behind a load balancer.
- If Tempo or Loki are unavailable, the collector will buffer in memory up to `memory_limiter` limits, then drop data.
- Monitor collector health via the Prometheus ServiceMonitor.

## Configuration Reference

### Operator Values (`otel-operator-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `replicaCount` | `1` | Single operator replica |
| `manager.resources.limits.memory` | `256Mi` | Operator memory limit |
| `manager.serviceMonitor.enabled` | `true` | Prometheus metrics |
| `admissionWebhooks.certManager.enabled` | `true` | cert-manager for webhook TLS |

### Collector + Instrumentation (`otel-config/collector-and-instrumentation.yaml`)

| Resource | Purpose |
|---|---|
| `OpenTelemetryCollector/otel-collector` | Centralized collector with OTLP receivers and LGTM exporters |
| `Instrumentation/python-instrumentation` | Python auto-instrumentation config |
| `Instrumentation/java-instrumentation` | Java auto-instrumentation config |
| `Instrumentation/nodejs-instrumentation` | Node.js auto-instrumentation config |
| `Instrumentation/go-instrumentation` | Go auto-instrumentation config |

## Useful Commands

| Task | Command |
|---|---|
| List collectors | `kubectl get opentelemetrycollectors -n opentelemetry` |
| List instrumentations | `kubectl get instrumentations -n opentelemetry` |
| Check collector logs | `kubectl logs -n opentelemetry -l app.kubernetes.io/name=otel-collector-collector` |
| Check operator logs | `kubectl logs -n opentelemetry -l app.kubernetes.io/name=opentelemetry-operator` |
| Verify instrumentation injection | `kubectl get pod <pod> -o jsonpath='{.spec.initContainers[*].name}'` (look for `opentelemetry-auto-instrumentation`) |

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Collector CrashLoopBackOff | Invalid exporter config (e.g., unsupported exporter type) | Check collector logs; verify exporter names match the collector distribution |
| Instrumentation not injected | Wrong annotation or namespace mismatch | Ensure annotation references `<namespace>/<instrumentation-name>` |
| No traces in Tempo | Collector can't reach Tempo endpoint | Check `tempo.monitoring.svc.cluster.local:4317` is reachable from opentelemetry namespace |
| Webhook failures | cert-manager certificate not ready | Check `kubectl get certificate -n opentelemetry` |

## Related Components

- **Tempo** -- Receives traces from the OTel Collector via OTLP gRPC.
- **Prometheus** -- Receives metrics from the OTel Collector's Prometheus exporter.
- **Loki** -- Receives logs from the OTel Collector via OTLP HTTP.
- **Grafana** -- Visualizes traces, metrics, and logs with cross-linking between data sources.
- **cert-manager** -- Issues TLS certificates for the operator's admission webhooks.
- **Grafana Alloy** -- Collects infrastructure logs and metrics separately; OTel handles application-level telemetry.
