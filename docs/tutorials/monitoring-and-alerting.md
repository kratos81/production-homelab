# Monitoring and Alerting with Prometheus, Grafana, Loki, and Tempo

## Overview

This tutorial covers the complete observability stack deployed on our RKE2 Kubernetes platform. You'll learn to monitor metrics, aggregate logs, trace requests, and set up intelligent alerting.

### The Observability Stack

Our platform uses four pillars of observability:

1. **Metrics** (Prometheus): Time-series data about system and application performance
2. **Logs** (Loki): Structured logs from all components via Grafana Alloy
3. **Traces** (Tempo): Distributed traces showing request flow through services
4. **Alerts** (AlertManager): Intelligent routing and notifications to Mattermost

All components run in the `monitoring` namespace with Grafana serving as the unified interface.

---

## Part 1: Accessing Grafana

### Port-Forward to Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open your browser to `http://localhost:3000` and log in with:
- **Username**: admin
- **Password**: admin

### Navigating Grafana

1. Click the **hamburger menu** (≡) in the top-left
2. Under **Dashboards**, click **Browse** to see auto-provisioned dashboards
3. Available dashboards:
   - ArgoCD (14584)
   - ingress-nginx (9614)
   - cert-manager (11001)
   - Harbor (14060)
   - MinIO (13502)
   - Vault (12904)
   - Keycloak (19659)
   - JupyterHub (17654)
   - Loki (13639)
   - Litmus (12096)

---

## Part 2: PromQL Queries

### Basic PromQL Concepts

PromQL is Prometheus Query Language. Time-series data is selected using metric name and label matchers.

### Query: Current Pod Count by Namespace

```promql
count(kube_pod_info) by (namespace)
```

This shows how many pods are running in each namespace.

### Query: CPU Usage Across the Cluster

```promql
sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)
```

Returns CPU cores consumed per namespace over the last 5 minutes.

### Query: Memory Utilization

```promql
sum(container_memory_usage_bytes) by (pod_name) / 1024 / 1024
```

Shows memory usage in MB per pod.

### Query: ArgoCD Application Sync Status

```promql
argocd_app_info{sync_status="Synced"}
```

Counts applications in sync state.

### Query: Ingress Request Rate

```promql
sum(rate(nginx_requests_total[1m])) by (exported_service)
```

Requests per second by service behind ingress-nginx.

### Query: Harbor Image Scan Status

```promql
harbor_image_scan_status{status="Success"}
```

Successfully scanned images count.

To test these queries:
1. Open Grafana and navigate to **Explore**
2. Select **Prometheus** as the data source
3. Paste a query in the text box
4. Click **Run Query**

---

## Part 3: Querying Logs with Loki

### LogQL Basics

LogQL uses label matchers and optional filter expressions.

### Query: All Logs from Monitoring Namespace

```logql
{namespace="monitoring"}
```

### Query: ArgoCD Application Controller Logs

```logql
{namespace="argocd"} | json | controller="application-controller"
```

Filters for JSON logs and extracts the controller field.

### Query: Error Logs from All Namespaces

```logql
{namespace!=""} | level="error"
```

Shows errors across the cluster.

### Query: Vault Audit Logs

```logql
{namespace="vault"} | json | type="response"
```

Filters Vault response audit logs.

### Query: Logs with Response Time

```logql
{job="loki"} | json | latency > 100
```

Shows operations taking over 100ms.

To query logs:
1. Go to **Explore** in Grafana
2. Select **Loki** as the data source
3. Paste a query and click **Run Query**
4. Click on any log line to see full details

---

## Part 4: Distributed Tracing with Tempo

### Accessing Tempo Traces

Traces are viewable directly in Grafana through the Tempo data source.

### Finding Traces

1. Go to **Explore** → Select **Tempo**
2. Search options:
   - **By service**: Select a service (e.g., "vault", "loki")
   - **By trace ID**: Paste a trace ID if you have one
   - **By tags**: Filter by custom attributes

### Example: Trace an ArgoCD Request

1. Go to **Explore** → **Tempo**
2. Select service: **argocd**
3. Click **Run Query**
4. Click a trace to see the waterfall diagram
5. Hover over spans to see duration and status

### Trace-to-Log Correlation

If logs are properly instrumented with trace IDs:

1. Open a trace in Tempo
2. Look for a "Logs" panel at the bottom
3. Associated logs appear automatically
4. Click a log to jump to Loki with that log highlighted

---

## Part 5: Creating Custom Grafana Dashboards

### Step 1: Create a New Dashboard

1. Click the **+** icon → **Create Dashboard**
2. Click **Add a new panel**

### Step 2: Configure a Panel

**Example: Memory Usage by Pod**

1. Set **Data source** to Prometheus
2. In the query field, enter:

```promql
topk(10, sum(container_memory_usage_bytes) by (pod_name) / 1024 / 1024)
```

3. Under **Options** → **Visualization**, select **Graph**
4. Set **Panel title** to "Top 10 Pod Memory Usage"
5. Click **Apply**

### Step 3: Add Thresholds and Alerts

1. Go to the **Alert** tab
2. Click **Create alert rule from this panel**
3. Set conditions (e.g., alert if memory > 500MB)
4. Set notification channel

### Step 4: Save the Dashboard

1. Click **Save** (top-right)
2. Give it a name, e.g., "Memory Usage Dashboard"
3. Click **Save**

---

## Part 6: Understanding ServiceMonitors

### What is a ServiceMonitor?

A ServiceMonitor tells Prometheus which services to scrape metrics from. Each monitored component has one.

### Viewing ServiceMonitors

```bash
kubectl get servicemonitor -n monitoring
```

Output shows all configured ServiceMonitors.

### Example: Examining the Vault ServiceMonitor

```bash
kubectl get servicemonitor -n monitoring vault-prometheus -o yaml
```

Key fields:
- **spec.selector**: Labels matching the service
- **spec.endpoints**: Port and path (/metrics)
- **spec.interval**: How often to scrape (default: 30s)

### Creating a Custom ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

Apply with:

```bash
kubectl apply -f servicemonitor.yaml
```

---

## Part 7: AlertManager Rules and Routing

### Viewing Alert Rules

```bash
kubectl get prometheusrule -n monitoring
```

### Checking AlertManager Configuration

```bash
kubectl get secret -n monitoring alertmanager-kube-prometheus-alertmanager -o yaml
```

The `alertmanager.yaml` key contains routing rules.

### Example: Alert for Pod Restart Loop

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: pod-restart-alerts
  namespace: monitoring
spec:
  groups:
  - name: pods
    interval: 30s
    rules:
    - alert: PodCrashLooping
      expr: increase(kube_pod_container_status_restarts_total[15m]) > 3
      for: 5m
      annotations:
        summary: "Pod {{ $labels.pod }} restarting frequently"
```

### Configuring Mattermost Webhook

AlertManager sends webhooks to Mattermost. Update the AlertManager secret:

```bash
kubectl edit secret -n monitoring alertmanager-kube-prometheus-alertmanager
```

Webhook URL format:

```
https://mattermost.example.com/hooks/webhook-id
```

---

## Hands-On Exercises

### Exercise 1: Find High CPU Usage

**Objective**: Identify the top 5 pods consuming CPU and note the highest one.

**Steps**:
1. Go to Grafana **Explore**
2. Select Prometheus
3. Query: `topk(5, rate(container_cpu_usage_seconds_total[5m]))`
4. Which pod uses the most CPU?

**Solution**: Your query should return pods sorted by CPU usage. Look at the top result.

---

### Exercise 2: Create a Memory Alert

**Objective**: Set up an alert if any pod exceeds 512MB memory.

**Steps**:
1. Create a PrometheusRule YAML file
2. Set expression: `container_memory_usage_bytes > 512*1024*1024`
3. Set `for: 2m` (alert if condition lasts 2 minutes)
4. Apply with `kubectl apply -f`
5. Check AlertManager UI at `http://localhost:9093` (port-forward if needed)

**Solution**:
```bash
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093
```
Then visit `http://localhost:9093` to see alerts.

---

### Exercise 3: Write a LogQL Query

**Objective**: Find all ERROR level logs from the vault namespace in the last hour.

**Steps**:
1. Go to Grafana **Explore** → **Loki**
2. Query: `{namespace="vault"} | level="error"`
3. How many error logs appear?

**Solution**: The query filters logs by namespace and level. Count the results in the panel.

---

### Exercise 4: Trace a Request

**Objective**: Find a trace from the vault service and identify the slowest span.

**Steps**:
1. Go to Grafana **Explore** → **Tempo**
2. Select service: **vault**
3. Click a trace to open the waterfall
4. Identify which span is slowest

**Solution**: Hover over spans to see duration. The slowest span should be visually apparent.

---

### Exercise 5: Build a Custom Dashboard

**Objective**: Create a dashboard with 3 panels: CPU, Memory, and Network I/O for the monitoring namespace.

**Steps**:
1. Create a new Grafana dashboard
2. Add panel 1 - CPU: `sum(rate(container_cpu_usage_seconds_total{namespace="monitoring"}[5m])) by (pod_name)`
3. Add panel 2 - Memory: `sum(container_memory_usage_bytes{namespace="monitoring"}) by (pod_name) / 1024 / 1024`
4. Add panel 3 - Network: `sum(rate(container_network_transmit_bytes_total{namespace="monitoring"}[1m])) by (pod_name)`
5. Save as "Monitoring Namespace Health"

**Solution**: All three panels should display data from your monitoring stack. Adjust time ranges with the time picker.

---

## Troubleshooting Common Issues

### Issue: No Data in Prometheus Query

**Solution**:
1. Verify ServiceMonitor exists: `kubectl get servicemonitor -n monitoring`
2. Check Prometheus targets: Port-forward to `http://localhost:9090`, click **Status** → **Targets**
3. Look for "DOWN" status and check the error

### Issue: Logs Not Appearing in Loki

**Solution**:
1. Verify Grafana Alloy is running: `kubectl get ds -n monitoring grafana-alloy`
2. Check Alloy logs: `kubectl logs -n monitoring -l app=alloy --tail=50`
3. Ensure labels are correct in log queries

### Issue: Traces Not Showing in Tempo

**Solution**:
1. Verify Tempo is receiving spans: `kubectl logs -n monitoring -l app.kubernetes.io/name=tempo --tail=50`
2. Ensure your applications export traces (check OTLP endpoints)
3. Check Tempo is configured as a Grafana data source

### Issue: AlertManager Not Sending to Mattermost

**Solution**:
1. Verify webhook URL in secret: `kubectl get secret -n monitoring alertmanager-kube-prometheus-alertmanager -o yaml | grep mattermost`
2. Test webhook manually with curl
3. Check AlertManager logs: `kubectl logs -n monitoring alertmanager-kube-prometheus-alertmanager-0`

---

## Additional Resources

- Prometheus Documentation: https://prometheus.io/docs/
- PromQL Examples: https://prometheus.io/docs/prometheus/latest/querying/examples/
- Grafana Dashboard Library: https://grafana.com/grafana/dashboards/
- Loki Documentation: https://grafana.com/docs/loki/
- Tempo Documentation: https://grafana.com/docs/tempo/

---

**Happy monitoring!** Remember: observability is not just about collecting data—it's about understanding your systems.
