# Backstage - Developer Portal

## Overview

Backstage provides a unified developer portal for service catalog management, documentation, and platform tooling. It acts as the central entry point for developers to discover services, APIs, and platform components deployed on this infrastructure.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on VMware vSphere / vCenter
- **Namespace**: `backstage`
- **Endpoint**: `https://backstage.homelab.local` via NGINX ingress with TLS
- **Image**: `ghcr.io/backstage/backstage:latest`
- **Database**: Bundled PostgreSQL with 5Gi persistent storage
- **Base URLs**: App and backend both configured to `https://backstage.homelab.local`

## Best Practices

### Security
- Move the PostgreSQL password (`BackstageDB2024!`) to a Kubernetes Secret referenced via `existingSecret`
- Pin the Backstage image to a specific version tag instead of `latest` for reproducible deployments
- Configure Backstage authentication with Keycloak OIDC to control access to the developer portal
- Restrict catalog entity registration to trusted Git repositories only
- Apply network policies to limit Backstage's access to only required backend services

### Performance
- Resource limits (500m CPU / 1Gi) are suitable for small to medium teams (~50 users)
- PostgreSQL limits (500m CPU / 512Mi) are adequate for catalog sizes under 1000 entities
- Enable Backstage search indexing with a scheduled task to keep search results current
- If the catalog grows large, consider increasing PostgreSQL memory and enabling connection pooling

### Reliability
- PostgreSQL persistence (5Gi) stores the service catalog and plugin data
- Back up PostgreSQL via Velero to prevent catalog data loss
- Monitor Backstage pod health; the app can become unresponsive if plugins have unhandled errors
- Use a custom Backstage Docker image with pre-installed plugins for faster, more reliable startups

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `backstage.image.registry` | `ghcr.io` | Container image registry |
| `backstage.image.repository` | `backstage/backstage` | Container image name |
| `backstage.image.tag` | `latest` | Image version tag |
| `backstage.resources.limits` | 500m CPU / 1Gi | Pod resource limits |
| `backstage.extraEnvVars: APP_CONFIG_app_baseUrl` | `https://backstage.homelab.local` | Frontend base URL |
| `backstage.extraEnvVars: APP_CONFIG_backend_baseUrl` | `https://backstage.homelab.local` | Backend base URL |
| `ingress.hosts[0].host` | `backstage.homelab.local` | External hostname |
| `postgresql.primary.persistence.size` | `5Gi` | Database storage |
| `postgresql.auth.password` | (set in values) | Database password |

## Common Operations and Troubleshooting

```bash
# Check Backstage pods
kubectl -n backstage get pods

# View Backstage application logs
kubectl -n backstage logs -l app.kubernetes.io/name=backstage -f

# Check PostgreSQL connectivity
kubectl -n backstage exec -it backstage-postgresql-0 -- psql -U postgres -c "SELECT 1;"

# Restart Backstage after configuration changes
kubectl -n backstage rollout restart deployment backstage

# Check catalog entity count
curl -s https://backstage.homelab.local/api/catalog/entities | jq 'length'

# Verify ingress and TLS
kubectl -n backstage get ingress
kubectl -n backstage get certificate

# Check database size
kubectl -n backstage exec -it backstage-postgresql-0 -- \
  psql -U postgres -c "SELECT pg_size_pretty(pg_database_size('backstage'));"
```

## Official Documentation

- Backstage Docs: https://backstage.io/docs/overview/what-is-backstage
- Backstage Helm Chart: https://github.com/backstage/charts
- Backstage Configuration: https://backstage.io/docs/conf/
- Backstage Plugin Marketplace: https://backstage.io/plugins
