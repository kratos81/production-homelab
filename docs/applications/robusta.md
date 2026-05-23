# Robusta Alert Enrichment

## Overview

Robusta is a Kubernetes observability platform that enriches Prometheus alerts with contextual information (logs, events, resource status) and automates investigation playbooks. It intercepts alerts from Alertmanager, runs enrichment actions, and can forward enriched alerts to various sinks.

## Architecture on This Platform

- **Cluster**: RKE2 Kubernetes on Harvester HCI, cluster name `rke2-cluster-02`
- **Deployment**: Managed via ArgoCD GitOps from `application/values/robusta-values.yaml`
- **Prometheus stack integration**: Disabled (`enablePrometheusStack: false`) -- uses the separately deployed kube-prometheus-stack
- **HolmesGPT integration**: Disabled in Robusta (`enableHolmesGPT: false`) -- HolmesGPT is deployed independently
- **Platform playbooks**: Enabled for automated alert enrichment
- **Global config**: Connected to Alertmanager, Prometheus, and Grafana in the `monitoring` namespace
- **Sinks**: Robusta UI sink configured (token placeholder)
- **Built-in playbooks** handle: KubePodCrashLooping, KubePodNotReady, KubeDeploymentReplicasMismatch, KubeContainerWaiting

## Best Practices

### Security
- The Robusta runner needs broad cluster RBAC to fetch logs, events, and resource details. Audit the ClusterRole periodically.
- The `robusta_ui_sink` token is currently empty -- configure a valid token or remove the sink to avoid errors.
- Keep Robusta's Alertmanager integration internal (ClusterIP); do not expose webhook endpoints externally.

### Performance
- The runner at 250m/512Mi request is sufficient for moderate alert volumes. Increase if playbook execution is slow.
- Playbooks run sequentially per alert; complex playbooks with multiple enrichers may delay processing under alert storms.
- Disable playbooks for noisy alerts that do not need enrichment to reduce runner load.

### Reliability
- Ensure Alertmanager is configured to route alerts to Robusta's webhook receiver.
- Test playbooks in a staging environment before adding them to production values.
- Monitor the runner pod for OOM or restarts, especially during incident cascades.

## Configuration Reference

| Key | Current Value | Purpose |
|-----|---------------|---------|
| `clusterName` | `rke2-cluster-02` | Cluster identifier in Robusta UI |
| `enablePrometheusStack` | `false` | Do not deploy bundled Prometheus |
| `enablePlatformPlaybooks` | `true` | Enable built-in enrichment playbooks |
| `enableHolmesGPT` | `false` | HolmesGPT managed separately |
| `runner.resources.requests` | `250m / 512Mi` | Runner CPU/memory requests |
| `runner.resources.limits` | `1 / 1Gi` | Runner CPU/memory limits |
| `globalConfig.alertmanager_url` | `...:9093` | Alertmanager endpoint |
| `globalConfig.prometheus_url` | `...:9090` | Prometheus endpoint |
| `globalConfig.grafana_url` | `...:80` | Grafana endpoint |
| `sinksConfig` | `robusta_ui_sink` | Alert destination sink |

### Configured Playbooks

| Alert | Enrichment Actions |
|-------|--------------------|
| `KubePodCrashLooping` | `logs_enricher`, `pod_events_enricher` |
| `KubePodNotReady` | `logs_enricher`, `pod_events_enricher` |
| `KubeDeploymentReplicasMismatch` | `deployment_events_enricher` |
| `KubeContainerWaiting` | `pod_issue_investigator` |

## Common Operations and Troubleshooting

- **Add a new playbook**: Append to `builtinPlaybooks` with a trigger (alert name) and actions (enrichers).
- **Test a playbook**: Manually fire a test alert via Alertmanager API and verify Robusta processes it.
- **Check runner logs**: `kubectl logs -l app=robusta-runner` for enrichment errors or connectivity issues.
- **Sink not receiving alerts**: Verify the sink token is valid and the Robusta UI endpoint is reachable.
- **Playbook not triggering**: Ensure the alert name in the trigger exactly matches the Prometheus alert rule name.

## Official Documentation

- Robusta: https://docs.robusta.dev/
- Robusta Playbooks: https://docs.robusta.dev/master/playbook-reference/
- Robusta Helm chart: https://github.com/robusta-dev/robusta/tree/master/helm
