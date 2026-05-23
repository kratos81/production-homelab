# Feast - Feature Store

## Overview

Feast provides a centralized feature store for ML workflows, enabling consistent feature serving for both training and inference. It stores feature definitions in a registry, uses PostgreSQL as an offline store, and Redis as an online store for low-latency feature retrieval.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on Harvester HCI
- **Namespace**: `ai-platform`
- **Components**: Feature server, PostgreSQL (offline/registry store), Redis (online store)
- **Feature Server**: Serves features via HTTP/gRPC for online inference
- **Offline Store**: PostgreSQL with 5Gi persistent storage
- **Online Store**: Redis with 2Gi persistent storage

## Best Practices

### Security
- Configure authentication on the feature server endpoint if exposed beyond the cluster
- Use Kubernetes Secrets for PostgreSQL and Redis credentials
- Apply network policies to restrict feature server access to authorized namespaces (KServe, JupyterHub)
- Audit feature access patterns to detect unauthorized data retrieval

### Performance
- Redis online store (250m CPU / 256Mi) is sized for moderate feature retrieval (~1000 QPS)
- For higher throughput, increase Redis resources and consider Redis Cluster mode
- Feature server resources (500m CPU / 512Mi) support moderate concurrent feature requests
- Batch feature retrieval (using `get_online_features` with multiple entities) is more efficient than individual lookups
- PostgreSQL offline store is suitable for batch feature generation during training

### Reliability
- Both PostgreSQL and Redis have persistence enabled, ensuring data survives pod restarts
- Back up PostgreSQL (feature registry and offline store) via Velero regularly
- Monitor Redis memory usage; eviction policies should be configured to avoid silent data loss
- Use feature versioning in Feast to manage schema changes safely

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `feast-feature-server.enabled` | `true` | Feature server deployed |
| `feast-feature-server.resources.limits` | 500m CPU / 512Mi | Feature server limits |
| `redis.enabled` | `true` | Redis online store enabled |
| `redis.master.resources.limits` | 250m CPU / 256Mi | Redis limits |
| `redis.master.persistence.size` | `2Gi` | Redis storage |
| `postgresql.enabled` | `true` | PostgreSQL offline store enabled |
| `postgresql.primary.resources.limits` | 500m CPU / 512Mi | PostgreSQL limits |
| `postgresql.primary.persistence.size` | `5Gi` | PostgreSQL storage |

## Common Operations and Troubleshooting

```bash
# Check Feast pods
kubectl -n ai-platform get pods -l app.kubernetes.io/name=feast

# View feature server logs
kubectl -n ai-platform logs -l app.kubernetes.io/component=feature-server -f

# Apply feature definitions
feast -c feature_repo/ apply

# List registered feature views
feast -c feature_repo/ feature-views list

# Test online feature retrieval
curl -s -X POST http://feast-feature-server.ai-platform.svc.cluster.local:6566/get-online-features \
  -H "Content-Type: application/json" \
  -d '{"features": ["feature_view:feature_name"], "entities": {"entity_id": [1]}}'

# Check Redis online store connectivity
kubectl -n ai-platform exec -it feast-redis-master-0 -- redis-cli ping

# Check PostgreSQL offline store
kubectl -n ai-platform exec -it feast-postgresql-0 -- psql -U postgres -c "\dt"

# Monitor Redis memory usage
kubectl -n ai-platform exec -it feast-redis-master-0 -- redis-cli info memory
```

## Official Documentation

- Feast Docs: https://docs.feast.dev/
- Feast Architecture: https://docs.feast.dev/getting-started/architecture
- Feast Helm Chart: https://github.com/feast-dev/feast/tree/master/infra/charts/feast
- Feast Feature Server: https://docs.feast.dev/reference/feature-servers
