# Chaos Engineering with Litmus -- Hands-On Tutorial

## Overview

This tutorial teaches chaos engineering principles and practice using Litmus Chaos on this platform. You will design experiments, inject failures, observe impact through Grafana, and learn to build resilience into your applications.

**Prerequisites**: `kubectl` access, Grafana port-forward, Litmus ChaosCenter port-forward.

**Platform Tools Used**: Litmus Chaos, Prometheus, Grafana, Loki, Robusta, Sample App

---

## 1. Why Break Things on Purpose?

Chaos engineering is the discipline of experimenting on a system to build confidence in its ability to withstand turbulent conditions in production.

### The Chaos Engineering Loop

```
   ┌──────────────┐
   │ 1. Define     │
   │ Steady State  │
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │ 2. Hypothesize│
   │ "App survives │
   │  pod deletion"│
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │ 3. Inject     │
   │ Chaos         │
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │ 4. Observe    │
   │ & Measure     │
   └──────┬───────┘
          │
   ┌──────▼───────┐
   │ 5. Learn &    │
   │ Improve       │
   └──────────────┘
```

### Key Principles

- **Start small** -- Begin with non-critical workloads (sample-app, not GitLab)
- **Minimize blast radius** -- Target one pod, not the whole namespace
- **Have abort conditions** -- Stop immediately if impact exceeds expectations
- **Run in production** -- After validating in staging, chaos in production finds real issues
- **Automate** -- Schedule regular chaos experiments, not just one-offs

---

## 2. Litmus Chaos Architecture

```
┌─────────────────────────────────────────────┐
│ ChaosCenter (UI)                             │
│ localhost:8185                                │
│ admin / litmus                               │
└──────────────┬──────────────────────────────┘
               │ creates
┌──────────────▼──────────────────────────────┐
│ ChaosEngine (CR)                             │
│ - References the target application          │
│ - References the ChaosExperiment             │
└──────────────┬──────────────────────────────┘
               │ triggers
┌──────────────▼──────────────────────────────┐
│ Chaos Runner (Pod)                           │
│ - Executes the experiment                    │
│ - Reports results back to ChaosEngine        │
└──────────────┬──────────────────────────────┘
               │ injects fault into
┌──────────────▼──────────────────────────────┐
│ Target Application                           │
│ (e.g., sample-app in sample-app namespace)   │
└─────────────────────────────────────────────┘
```

### Accessing Litmus ChaosCenter

```bash
# Port-forward ChaosCenter UI
kubectl port-forward svc/chaos-litmus-frontend-service -n litmus 8185:9091

# Open browser
open http://localhost:8185
# Login: admin / litmus
```

---

## 3. Before You Start: Establish Steady State

Before any experiment, record baseline metrics:

```bash
# Port-forward Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80

# Check sample-app is healthy
curl -sk https://sample-app.homelab.local/health
# Expected: {"status":"ok"}

# Record baseline metrics
curl -sk https://sample-app.homelab.local/metrics | grep http_requests_total

# Verify pod count
kubectl get pods -n sample-app
```

In Grafana (localhost:3000), open the ingress-nginx dashboard and note the current request rate and error rate.

---

## 4. Hands-On: Pod Delete Experiment

### Step 1: Create the ChaosExperiment

```yaml
# Save as pod-delete-experiment.yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: sample-app-pod-delete
  namespace: sample-app
spec:
  appinfo:
    appns: sample-app
    applabel: "app.kubernetes.io/name=sample-app"
    appkind: deployment
  engineState: active
  chaosServiceAccount: litmus-admin
  experiments:
    - name: pod-delete
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: "30"
            - name: CHAOS_INTERVAL
              value: "10"
            - name: FORCE
              value: "false"
```

```bash
# Apply the experiment
kubectl apply -f pod-delete-experiment.yaml

# Watch the chaos
kubectl get pods -n sample-app -w

# Check experiment status
kubectl get chaosengine -n sample-app sample-app-pod-delete -o jsonpath='{.status.engineStatus}'

# Check the result
kubectl get chaosresult -n sample-app -o wide
```

### Step 2: Observe in Grafana

While the experiment runs:
1. Open Grafana at `localhost:3000`
2. Navigate to the ingress-nginx dashboard
3. Watch for request failures or latency spikes
4. Check Loki logs: `{namespace="sample-app"}`

### Step 3: Validate Recovery

```bash
# After chaos ends, verify the app recovered
curl -sk https://sample-app.homelab.local/health

# Check pod count is restored
kubectl get pods -n sample-app
```

---

## 5. Hands-On: Network Chaos

Inject network latency into a service:

```yaml
# Save as network-chaos.yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: sample-app-network-chaos
  namespace: sample-app
spec:
  appinfo:
    appns: sample-app
    applabel: "app.kubernetes.io/name=sample-app"
    appkind: deployment
  engineState: active
  chaosServiceAccount: litmus-admin
  experiments:
    - name: pod-network-latency
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: "60"
            - name: NETWORK_LATENCY
              value: "2000"       # 2 second latency
            - name: NETWORK_INTERFACE
              value: "eth0"
```

```bash
kubectl apply -f network-chaos.yaml

# Measure latency during chaos
time curl -sk https://sample-app.homelab.local/health
# Should show ~2 second response time

# Compare with normal (after chaos ends)
time curl -sk https://sample-app.homelab.local/health
# Should show <100ms
```

### Network Packet Loss

```yaml
experiments:
  - name: pod-network-loss
    spec:
      components:
        env:
          - name: TOTAL_CHAOS_DURATION
            value: "60"
          - name: NETWORK_PACKET_LOSS_PERCENTAGE
            value: "50"          # 50% packet loss
          - name: NETWORK_INTERFACE
            value: "eth0"
```

---

## 6. Hands-On: CPU and Memory Stress

### CPU Stress

```yaml
# Save as cpu-stress.yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: sample-app-cpu-stress
  namespace: sample-app
spec:
  appinfo:
    appns: sample-app
    applabel: "app.kubernetes.io/name=sample-app"
    appkind: deployment
  engineState: active
  chaosServiceAccount: litmus-admin
  experiments:
    - name: pod-cpu-hog
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: "60"
            - name: CPU_CORES
              value: "1"
            - name: CPU_LOAD
              value: "100"
```

```bash
kubectl apply -f cpu-stress.yaml

# Monitor CPU in Grafana or via kubectl
kubectl top pods -n sample-app
```

### Memory Stress

```yaml
experiments:
  - name: pod-memory-hog
    spec:
      components:
        env:
          - name: TOTAL_CHAOS_DURATION
            value: "60"
          - name: MEMORY_CONSUMPTION
            value: "500"          # 500 MB
```

Watch in Grafana for memory usage spikes and potential OOMKills.

---

## 7. Hands-On: Node Drain Simulation

**Warning**: This affects all pods on the node. Use with caution.

```yaml
apiVersion: litmuschaos.io/v1alpha1
kind: ChaosEngine
metadata:
  name: node-drain-test
  namespace: litmus
spec:
  engineState: active
  chaosServiceAccount: litmus-admin
  experiments:
    - name: node-drain
      spec:
        components:
          env:
            - name: TOTAL_CHAOS_DURATION
              value: "60"
            - name: TARGET_NODE
              value: "rke2-cluster-02-worker-3"   # Pick a specific worker
```

**Before running**: Verify which pods run on the target node:

```bash
kubectl get pods --all-namespaces --field-selector spec.nodeName=rke2-cluster-02-worker-3
```

---

## 8. Observing Chaos in Grafana

### Key Metrics to Watch

```promql
# Request error rate during chaos
rate(nginx_ingress_controller_requests{status=~"5.."}[5m])

# Pod restart count
kube_pod_container_status_restarts_total{namespace="sample-app"}

# Pod not ready
kube_pod_status_ready{namespace="sample-app", condition="true"}

# CPU throttling
container_cpu_cfs_throttled_seconds_total{namespace="sample-app"}
```

### Correlating with Loki Logs

In Grafana Explore, use LogQL:

```logql
# Errors during chaos window
{namespace="sample-app"} |= "error" | json

# Kubernetes events
{namespace="sample-app", stream="stderr"}

# Litmus chaos runner logs
{namespace="sample-app", app="chaos-runner"}
```

---

## 9. Designing a Chaos Experiment

### Template

| Field | Value |
|---|---|
| **Experiment Name** | `[app]-[fault-type]-[date]` |
| **Hypothesis** | "The app will continue serving requests within 5s latency during pod deletion" |
| **Steady State** | Request rate: 100 rps, Error rate: <0.1%, P99 latency: <200ms |
| **Blast Radius** | Single pod in sample-app namespace |
| **Duration** | 30 seconds |
| **Abort Condition** | Error rate exceeds 50% OR all pods are down |
| **Expected Outcome** | Kubernetes reschedules the pod; requests fail for <5 seconds |
| **Actual Outcome** | (Fill after experiment) |
| **Action Items** | (Fill after experiment) |

---

## 10. GameDay Planning

A GameDay is a structured chaos engineering session with your team.

### Agenda (2 hours)

| Time | Activity |
|---|---|
| 0:00 - 0:15 | Introduction, review steady state metrics |
| 0:15 - 0:30 | Present experiment hypotheses |
| 0:30 - 1:00 | Run experiments (pod delete, network chaos) |
| 1:00 - 1:15 | Break |
| 1:15 - 1:45 | Run advanced experiments (CPU stress, node drain) |
| 1:45 - 2:00 | Retrospective -- findings, action items |

### GameDay Checklist

- [ ] All team members have Grafana access
- [ ] Litmus ChaosCenter accessible
- [ ] Alert channels (Mattermost) monitored
- [ ] Runbook for manual intervention ready
- [ ] Steady state baselines recorded
- [ ] Stakeholders notified

---

## 11. Exercises

### Exercise 1: Your First Pod Delete

**Task**: Run a pod-delete experiment against the sample-app. Record the time-to-recovery.

```bash
# Solution: Apply the ChaosEngine from Section 4
# Measure recovery time
kubectl get pods -n sample-app -w
# Note: Kubernetes typically restarts within 5-15 seconds
```

### Exercise 2: Measure Latency Impact

**Task**: Inject 500ms network latency into sample-app and measure the P99 response time in Grafana.

```bash
# Modify the network-chaos.yaml with NETWORK_LATENCY=500
# Apply and measure
for i in $(seq 1 20); do time curl -sk https://sample-app.homelab.local/health 2>&1 | grep real; done
```

### Exercise 3: Stress Test with Monitoring

**Task**: Run a CPU stress experiment and create a Grafana panel showing CPU usage during the chaos window.

```bash
# Apply cpu-stress.yaml from Section 6
# In Grafana, create a panel with:
# container_cpu_usage_seconds_total{namespace="sample-app"}
```

### Exercise 4: Multi-Fault Experiment

**Task**: Run pod-delete and network-latency simultaneously. How does the application behave compared to each fault individually?

### Exercise 5: Write a ChaosWorkflow

**Task**: Using Litmus ChaosCenter UI, create a workflow that:
1. Runs pod-delete for 30s
2. Waits 60s for recovery
3. Runs network-latency for 30s
4. Waits 60s for recovery
5. Records overall pass/fail

---

## 12. Safety Best Practices

| Practice | Description |
|---|---|
| **Start with non-critical workloads** | Use sample-app first, not GitLab or Vault |
| **Set TOTAL_CHAOS_DURATION** | Always limit experiment duration |
| **Use `engineState: stop`** | Abort immediately by patching the ChaosEngine |
| **Monitor during experiments** | Keep Grafana and Mattermost open |
| **Document everything** | Record hypotheses, results, and action items |
| **Notify stakeholders** | Alert the team before running chaos experiments |
| **Have rollback plan** | Know how to restart affected services |
| **Gradual escalation** | Pod delete → network chaos → node drain (increasing blast radius) |

### Emergency Abort

```bash
# Stop a running experiment immediately
kubectl patch chaosengine sample-app-pod-delete -n sample-app \
  --type merge -p '{"spec":{"engineState":"stop"}}'

# Delete all chaos resources
kubectl delete chaosengine --all -n sample-app
```

---

## Next Steps

- [Monitoring & Alerting Tutorial](monitoring-and-alerting.md) -- Set up alerts for chaos experiment metrics
- [AIOps Tutorial](aiops.md) -- Use HolmesGPT and K8sGPT to analyze chaos experiment impact
- [Security Tutorial](security.md) -- Ensure chaos experiments don't violate Kyverno policies
