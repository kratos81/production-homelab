# AIOps for Kubernetes -- Hands-On Tutorial

## Overview

This tutorial teaches AIOps (Artificial Intelligence for IT Operations) using the AI-powered tools on this platform. You will use HolmesGPT for root cause analysis, K8sGPT for diagnostics, Robusta for automated remediation, and OpenCost for cost optimization.

**Prerequisites**: `kubectl` access, Grafana port-forward, Ollama running in the cluster.

**Platform Tools Used**: HolmesGPT, K8sGPT, Robusta, OpenCost, Ollama, Prometheus, Grafana

---

## 1. What is AIOps?

AIOps applies AI/ML to IT operations to automate:

- **Detection** -- Identify issues faster than humans can monitor dashboards
- **Diagnosis** -- Root cause analysis using LLMs that understand Kubernetes
- **Remediation** -- Automated playbooks that fix known issues without human intervention
- **Optimization** -- Cost analysis and resource right-sizing recommendations

### AIOps Stack on This Platform

```
┌─────────────────────────────────────────────────────┐
│                    Ollama (LLM Backend)               │
│              llama3.2:3b / codellama:7b               │
│         ollama.ai-platform.svc.cluster.local:11434    │
└───────────┬──────────────────┬───────────────────────┘
            │                  │
┌───────────▼──────┐  ┌───────▼──────────┐
│   HolmesGPT      │  │    K8sGPT        │
│   (RCA Agent)     │  │    (Diagnostics) │
│   Queries:        │  │    Scans:        │
│   - Prometheus    │  │    - CrashLoops  │
│   - AlertManager  │  │    - OOMKills    │
│   - K8s API       │  │    - Failed deps │
└──────────────────┘  └──────────────────┘

┌──────────────────┐  ┌──────────────────┐
│   Robusta         │  │    OpenCost      │
│   (Remediation)   │  │    (FinOps)      │
│   Playbooks:      │  │    Tracks:       │
│   - CrashLoop fix │  │    - CPU cost    │
│   - Alert enrich  │  │    - Memory cost │
│   - Pod restart   │  │    - Per-ns cost │
└──────────────────┘  └──────────────────┘
```

---

## 2. HolmesGPT Deep Dive

HolmesGPT (CNCF Sandbox) is an AI troubleshooting agent that uses an **agentic loop** -- it formulates queries, executes them against Prometheus/AlertManager/Kubernetes, reads the results, and iterates until it finds the root cause.

### Architecture

1. Receives an alert or question
2. LLM (Ollama llama3.2:3b) generates investigation queries
3. Toolsets execute queries (PromQL, kubectl, AlertManager API)
4. LLM analyzes results and generates next query or conclusion
5. Returns root cause analysis with evidence

### Accessing HolmesGPT

```bash
# Port-forward
kubectl port-forward svc/holmesgpt-holmes -n monitoring 8180:80

# Ask HolmesGPT about a specific alert
curl -X POST http://localhost:8180/api/investigate \
  -H "Content-Type: application/json" \
  -d '{
    "source": "prometheus",
    "title": "High memory usage in gitlab namespace",
    "description": "Memory usage exceeds 80% in gitlab namespace"
  }'
```

### Hands-On: Investigate an Alert

```bash
# Step 1: Check current alerts
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {alertname: .labels.alertname, state: .state}'

# Step 2: Pick an alert and ask HolmesGPT
curl -X POST http://localhost:8180/api/investigate \
  -H "Content-Type: application/json" \
  -d '{
    "source": "prometheus",
    "title": "KubePodNotReady",
    "description": "Pod not ready for more than 15 minutes"
  }'

# Step 3: Review the investigation
# HolmesGPT will return:
# - Root cause hypothesis
# - Evidence (metrics, logs, events)
# - Recommended actions
```

---

## 3. K8sGPT Deep Dive

K8sGPT runs as an operator that continuously scans the cluster for issues and stores AI-powered diagnostics as Kubernetes Custom Resources.

### How It Works

```
K8sGPT Operator
    │
    ├── Scans all namespaces for:
    │   ├── CrashLoopBackOff pods
    │   ├── OOMKilled containers
    │   ├── Failed deployments
    │   ├── Pending PVCs
    │   ├── Misconfigured services
    │   └── Event anomalies
    │
    ├── Sends findings to Ollama (llama3.2:3b)
    │
    └── Stores results as K8sGPT Result CRs
```

### Viewing K8sGPT Results

```bash
# List all K8sGPT findings
kubectl get results -n k8sgpt

# View a specific result
kubectl get results -n k8sgpt <result-name> -o yaml

# View all results with details
kubectl get results -n k8sgpt -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.details}{"\n"}{end}'
```

### Hands-On: Trigger an Issue for K8sGPT

```bash
# Step 1: Create a broken deployment
kubectl create deployment broken-app --image=nginx:nonexistent -n default

# Step 2: Wait 2-3 minutes for K8sGPT to scan

# Step 3: Check K8sGPT results
kubectl get results -n k8sgpt

# Step 4: Read the AI diagnosis
kubectl get results -n k8sgpt -o yaml | grep -A 10 "broken-app"

# Step 5: Clean up
kubectl delete deployment broken-app -n default
```

K8sGPT will identify the `ImagePullBackOff` and explain that the image tag doesn't exist.

---

## 4. Robusta Deep Dive

Robusta integrates with Prometheus AlertManager to automatically enrich alerts and run remediation playbooks.

### Built-in Playbooks

| Playbook | Trigger | Action |
|---|---|---|
| `crash_loop_reporter` | CrashLoopBackOff | Collects pod logs, events, and previous container output |
| `pod_not_ready_reporter` | PodNotReady | Gathers readiness probe details and node conditions |
| `deployment_mismatch_reporter` | ReplicaMismatch | Reports desired vs actual replica counts |
| `oom_kill_reporter` | OOMKilled | Shows memory limits, actual usage, and container stats |

### How Alerts Flow

```
Prometheus → AlertManager → Robusta → Enriched Alert → Mattermost
                                  │
                                  └── Runs playbook (collects logs, events, etc.)
```

### Hands-On: Custom Robusta Playbook

Create a playbook that collects extra information when any pod crashes:

```yaml
# Example custom playbook (add to robusta-values.yaml)
customPlaybooks:
  - triggers:
      - on_pod_crash_loop:
          restart_reason: "CrashLoopBackOff"
    actions:
      - event_report: {}
      - logs_enricher:
          regex_replacer_patterns:
            - regex: "password=.*"
              replacement: "password=***"
```

---

## 5. OpenCost Deep Dive

OpenCost provides real-time cost allocation for every namespace, deployment, and pod.

### Accessing OpenCost

```bash
# Web UI
open https://opencost.homelab.local

# API queries
curl -s "https://opencost.homelab.local/allocation/compute?window=24h&aggregate=namespace" | jq '.'
```

### Understanding Cost Allocation

```bash
# Cost by namespace (last 24h)
curl -s "https://opencost.homelab.local/allocation/compute?window=24h&aggregate=namespace" | \
  jq '.data[] | to_entries[] | {namespace: .key, cpuCost: .value.cpuCost, ramCost: .value.ramCost, totalCost: .value.totalCost}'

# Cost by deployment
curl -s "https://opencost.homelab.local/allocation/compute?window=7d&aggregate=deployment" | \
  jq '.data[] | to_entries[] | select(.value.totalCost > 0.01) | {deployment: .key, totalCost: .value.totalCost}' | \
  sort_by(.totalCost) | reverse

# Idle resources (waste)
curl -s "https://opencost.homelab.local/allocation/compute?window=24h&aggregate=namespace" | \
  jq '.data[] | to_entries[] | {namespace: .key, cpuEfficiency: .value.cpuEfficiency, ramEfficiency: .value.ramEfficiency}'
```

### Hands-On: Finding Optimization Opportunities

```bash
# Step 1: Identify over-provisioned namespaces
# Look for namespaces where cpuEfficiency < 0.2 (using less than 20% of requested CPU)

# Step 2: Check actual usage vs requests
kubectl top pods -n <namespace>
kubectl get pods -n <namespace> -o jsonpath='{range .items[*]}{.metadata.name}: CPU={.spec.containers[0].resources.requests.cpu}, Mem={.spec.containers[0].resources.requests.memory}{"\n"}{end}'

# Step 3: Right-size resources
# Edit the values file for the identified application
# Reduce CPU/memory requests to match actual usage + 20% buffer
```

---

## 6. Combined AIOps Incident Response Workflow

When an alert fires, here's how all AIOps tools work together:

```
1. Alert fires in Prometheus
       │
2. AlertManager sends to:
       ├── Mattermost (human notification)
       └── Robusta (enrichment + playbook)
               │
3. Robusta enriches alert with:
       ├── Pod logs
       ├── Events
       └── Container stats
               │
4. Team investigates using:
       ├── HolmesGPT (AI root cause analysis)
       ├── K8sGPT results (cluster-wide diagnostics)
       ├── Grafana dashboards (metrics visualization)
       └── Loki logs (log correlation)
               │
5. Resolution applied, OpenCost tracks impact
```

### Hands-On: Simulate an Incident

```bash
# Step 1: Create a memory-hungry pod that will get OOMKilled
kubectl run memory-hog --image=polinux/stress -n default -- \
  stress --vm 1 --vm-bytes 512M --vm-hang 0

# Step 2: Watch the alert fire in Mattermost

# Step 3: Check Robusta enrichment
kubectl logs -n robusta -l app=robusta-runner --tail=50

# Step 4: Ask HolmesGPT about the OOMKill
curl -X POST http://localhost:8180/api/investigate \
  -H "Content-Type: application/json" \
  -d '{"title": "OOMKilled pod in default namespace"}'

# Step 5: Check K8sGPT
kubectl get results -n k8sgpt

# Step 6: Check cost impact in OpenCost
curl -s "https://opencost.homelab.local/allocation/compute?window=1h&aggregate=namespace&filterNamespaces=default"

# Step 7: Clean up
kubectl delete pod memory-hog -n default
```

---

## 7. Exercises

### Exercise 1: HolmesGPT Investigation

**Task**: Create a deployment with a misconfigured readiness probe and use HolmesGPT to diagnose why the pod is not ready.

```bash
# Create the broken deployment
kubectl create deployment probe-test --image=nginx -n default
kubectl patch deployment probe-test -n default --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/readinessProbe", "value": {
    "httpGet": {"path": "/nonexistent", "port": 80},
    "initialDelaySeconds": 5, "periodSeconds": 5
  }}
]'

# Wait for K8sGPT to detect and HolmesGPT to analyze
# Then clean up: kubectl delete deployment probe-test -n default
```

### Exercise 2: K8sGPT Cluster Health Report

**Task**: List all current K8sGPT findings and categorize them by severity. Which namespace has the most issues?

```bash
kubectl get results -n k8sgpt -o json | \
  jq '.items[] | {name: .metadata.name, kind: .spec.kind, details: .spec.details}'
```

### Exercise 3: OpenCost Analysis

**Task**: Identify the top 5 most expensive namespaces and calculate the total monthly cluster cost.

```bash
curl -s "https://opencost.homelab.local/allocation/compute?window=30d&aggregate=namespace" | \
  jq '[.data[] | to_entries[] | {ns: .key, cost: .value.totalCost}] | flatten | sort_by(.cost) | reverse | .[0:5]'
```

### Exercise 4: Robusta Alert Enrichment

**Task**: Trigger a CrashLoopBackOff and verify that Robusta collects pod logs and events in the enriched alert.

```bash
# Create a crashing pod
kubectl run crasher --image=busybox -n default -- /bin/sh -c "exit 1"

# Check Robusta logs for enrichment
kubectl logs -n robusta -l app=robusta-runner --tail=100 | grep -i crash

# Clean up
kubectl delete pod crasher -n default
```

### Exercise 5: End-to-End Incident Response

**Task**: Combine all tools: create an issue, get HolmesGPT diagnosis, check K8sGPT results, review Robusta enrichment, and find the cost impact in OpenCost. Document your findings.

---

## 8. AIOps Maturity Model

| Level | Description | Platform Coverage |
|---|---|---|
| **Level 0: Manual** | Human monitors dashboards, manually investigates | Prometheus + Grafana |
| **Level 1: Assisted** | AI helps diagnose but humans take all actions | + HolmesGPT, K8sGPT |
| **Level 2: Automated Detection** | AI detects and classifies issues automatically | + Robusta alert enrichment |
| **Level 3: Automated Remediation** | AI fixes known issues without human intervention | + Robusta playbooks |
| **Level 4: Predictive** | AI predicts failures before they happen | Future: anomaly detection ML models |
| **Level 5: Autonomous** | AI manages the cluster end-to-end | Future: full autonomous operations |

This platform is at **Level 2-3**, with HolmesGPT/K8sGPT for detection and Robusta for automated remediation of common issues.

---

## Next Steps

- [Monitoring & Alerting Tutorial](monitoring-and-alerting.md) -- Create Prometheus alerts that trigger AIOps tools
- [Chaos Engineering Tutorial](chaos-engineering.md) -- Use AIOps tools to analyze chaos experiment impact
- [GitOps Tutorial](gitops.md) -- Manage AIOps tool configurations through GitOps
