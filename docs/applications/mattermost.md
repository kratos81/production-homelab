# Mattermost -- Best Practices and Configuration Guide

## Overview

Mattermost Team Edition is an open-source, self-hosted team messaging platform. On this platform it serves as the notification hub for AlertManager alerts and team communication during incident response.

- **Chart**: `mattermost-team-edition` from `https://helm.mattermost.com`
- **Version**: 9.11
- **Namespace**: `mattermost`
- **Sync Wave**: 15
- **URL**: `https://mattermost.homelab.local`

## Architecture

```
                    ┌──────────────────────┐
                    │    ingress-nginx      │
                    │ mattermost.homelab.local│
                    └──────────┬───────────┘
                               │
                    ┌──────────▼───────────┐
                    │   Mattermost Server   │
                    │   (Team Edition 9.11) │
                    │   Port 8065           │
                    └──────┬──────┬────────┘
                           │      │
              ┌────────────▼┐  ┌──▼───────────┐
              │   MySQL DB   │  │  PVC Storage  │
              │  mattermost  │  │  data: 10Gi   │
              │  Port 3306   │  │  plugins: 1Gi │
              └──────────────┘  └───────────────┘

AlertManager ──webhook──► Mattermost Incoming Webhook
```

## Configuration Reference

### Key Values

| Setting | Value | Description |
|---|---|---|
| `image.tag` | `9.11` | Mattermost Team Edition version |
| `ingress.enabled` | `true` | Expose via ingress-nginx |
| `ingress.className` | `nginx` | Ingress class |
| `persistence.data.size` | `10Gi` | File attachments and uploads |
| `persistence.plugins.size` | `1Gi` | Plugin storage |
| `mysql.enabled` | `true` | Bundled MySQL database |
| `mysql.mysqlDatabase` | `mattermost` | Database name |
| `configJSON.ServiceSettings.EnableIncomingWebhooks` | `true` | Required for AlertManager |

### Resource Allocation

| Component | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---|---|---|---|---|
| Mattermost Server | 250m | 1 | 256Mi | 1Gi |
| MySQL | 100m | 500m | 256Mi | 512Mi |

## Best Practices

### 1. Incoming Webhooks for AlertManager

After Mattermost is deployed and you've created a team/channel:

1. Log into Mattermost at `https://mattermost.homelab.local`
2. Go to **Main Menu** > **Integrations** > **Incoming Webhooks**
3. Click **Add Incoming Webhook**
4. Select the channel (e.g., `alerts`)
5. Copy the webhook URL (ends with `/hooks/<webhook-id>`)
6. Update `prometheus-values.yaml` AlertManager config with the webhook ID

### 2. Channel Organization

Create dedicated channels for different alert severities:

| Channel | Purpose |
|---|---|
| `#alerts-critical` | P1 incidents requiring immediate action |
| `#alerts-warning` | P2 issues to investigate during business hours |
| `#chaos-experiments` | Litmus chaos experiment notifications |
| `#deployments` | ArgoCD sync notifications |
| `#general` | Team communication |

### 3. Database Backup

MySQL data is stored on a PVC. Include the `mattermost` namespace in Velero backup schedules:

```bash
# Verify Mattermost PVCs are backed up
velero backup describe daily-backup --details | grep mattermost
```

### 4. Performance Tuning

For larger teams, adjust:

```yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2
    memory: 2Gi
```

### 5. Proxy Timeouts

The ingress annotations are configured for WebSocket support:

```yaml
nginx.ingress.kubernetes.io/proxy-body-size: "50m"
nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
```

These are required for real-time messaging and file uploads up to 50MB.

## Security Considerations

- **Change default MySQL password** before production use
- Enable **MFA** in Mattermost System Console for all users
- Configure **email verification** if SMTP is available
- Set `EnableOpenServer: false` after initial user registration to prevent unauthorized signups
- Use Keycloak OIDC integration for SSO (requires Mattermost Enterprise or plugin)

## Troubleshooting

### Mattermost pod CrashLoopBackOff

```bash
# Check logs
kubectl logs -n mattermost deploy/mattermost-team-edition

# Common cause: MySQL not ready yet
kubectl get pods -n mattermost
# Wait for mysql pod to be Running before mattermost starts
```

### Webhooks not working

```bash
# Verify webhooks are enabled
kubectl exec -n mattermost deploy/mattermost-team-edition -- \
  cat /mattermost/config/config.json | jq '.ServiceSettings.EnableIncomingWebhooks'

# Test webhook manually
curl -X POST -H 'Content-Type: application/json' \
  -d '{"text": "Test alert from CLI"}' \
  http://mattermost-team-edition.mattermost.svc.cluster.local:8065/hooks/<webhook-id>
```

### MySQL connection errors

```bash
# Check MySQL pod
kubectl logs -n mattermost -l app=mysql

# Verify MySQL credentials
kubectl get secret -n mattermost mattermost-team-edition-mysql -o yaml
```

### File upload failures

If uploads fail with 413 errors, the ingress proxy-body-size annotation may be missing:

```bash
kubectl get ingress -n mattermost -o yaml | grep proxy-body-size
```

## Official Links

- [Mattermost Documentation](https://docs.mattermost.com/)
- [Mattermost Helm Chart](https://github.com/mattermost/mattermost-helm)
- [Incoming Webhooks Guide](https://developers.mattermost.com/integrate/webhooks/incoming/)
- [AlertManager Webhook Configuration](https://prometheus.io/docs/alerting/latest/configuration/#webhook_config)
