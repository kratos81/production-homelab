# Litmus Chaos Engineering

## Overview

Litmus is a CNCF chaos engineering platform for Kubernetes. It enables teams to inject controlled failures (pod kill, network latency, CPU stress, etc.) to validate system resilience. Litmus provides a web portal for designing, scheduling, and observing chaos experiments.

## Architecture on This Platform

- **Cluster**: RKE2 Kubernetes on Proxmox VE
- **Deployment**: Managed via ArgoCD GitOps from `application/values/litmus-values.yaml`
- **Components**:
  - **Portal frontend**: Web UI (ClusterIP service)
  - **GraphQL server**: Backend API for experiment management
  - **Auth server**: User authentication and authorization
  - **MongoDB**: Persistent state store for experiments, schedules, and results (5Gi PVC)
- **Monitoring**: Litmus Chaos Grafana dashboard provisioned via kube-prometheus-stack (gnetId 12096)

## Best Practices

### Security
- The auth server handles user management; configure strong credentials and consider integrating with Keycloak for SSO.
- Litmus chaos experiments require elevated RBAC (pod deletion, network manipulation). Use dedicated ServiceAccounts with least-privilege roles scoped to target namespaces.
- Do not run chaos experiments against the `monitoring` or `kube-system` namespaces in production without careful planning.
- The frontend is ClusterIP only; expose via Ingress with TLS and authentication for user access.

### Performance
- MongoDB at 250m/256Mi is adequate for moderate experiment history. Increase if running hundreds of experiments.
- The GraphQL server (250m/256Mi request, 500m/512Mi limit) handles experiment orchestration; monitor during concurrent experiment runs.
- Archive or clean up old experiment results periodically to keep MongoDB performant.

### Reliability
- MongoDB persistence (5Gi) ensures experiment data survives restarts. Monitor disk usage and expand as needed.
- Test chaos experiments in a staging environment before running against production workloads.
- Use steady-state hypotheses in experiments to automatically validate that the system returns to normal after chaos.
- Schedule experiments during maintenance windows for critical infrastructure.

## Configuration Reference

| Key | Current Value | Purpose |
|-----|---------------|---------|
| `portal.frontend.service.type` | `ClusterIP` | Frontend service type |
| `portal.frontend.resources.requests` | `100m / 128Mi` | Frontend CPU/memory requests |
| `portal.frontend.resources.limits` | `250m / 256Mi` | Frontend CPU/memory limits |
| `portal.server.graphqlServer.resources.requests` | `250m / 256Mi` | GraphQL server requests |
| `portal.server.graphqlServer.resources.limits` | `500m / 512Mi` | GraphQL server limits |
| `portal.server.authServer.resources.requests` | `100m / 128Mi` | Auth server requests |
| `portal.server.authServer.resources.limits` | `250m / 256Mi` | Auth server limits |
| `mongodb.persistence.enabled` | `true` | Persistent MongoDB storage |
| `mongodb.persistence.size` | `5Gi` | MongoDB PVC size |
| `mongodb.resources.requests` | `250m / 256Mi` | MongoDB CPU/memory requests |
| `mongodb.resources.limits` | `500m / 512Mi` | MongoDB CPU/memory limits |

## Common Operations and Troubleshooting

- **Access the portal**: Port-forward or expose via Ingress: `kubectl port-forward svc/litmus-frontend 9091:9091`.
- **Create an experiment**: Use the portal UI to select a chaos fault, define the target (namespace, labels), and set the schedule.
- **Monitor experiment**: View real-time status in the Litmus portal or check the Litmus Chaos Grafana dashboard.
- **MongoDB connection issues**: Check MongoDB pod logs and PVC status: `kubectl get pvc -l app=mongodb`.
- **Experiment stuck in "Running"**: Check the chaos runner pod in the target namespace for RBAC or scheduling errors.
- **Clean up experiments**: Delete completed experiment runs via the portal or `kubectl delete chaosresult --all`.

## Official Documentation

- Litmus: https://litmuschaos.io/
- Litmus Docs: https://docs.litmuschaos.io/
- Litmus Helm chart: https://github.com/litmuschaos/litmus-helm
- ChaosHub (experiment catalog): https://hub.litmuschaos.io/
