# GitLab CE - Source Code Management

## Overview

GitLab Community Edition provides Git repository hosting, CI/CD pipelines, and code collaboration for the platform. It is deployed as a minimal installation with non-essential components disabled to conserve resources on the Harvester HCI cluster.

## Architecture on This Platform

- **Platform**: RKE2 Kubernetes on Harvester HCI
- **Edition**: Community Edition (CE)
- **Domain**: `gitlab.homelab.local` via NGINX ingress with TLS (cert-manager `homelab-ca-issuer`)
- **Storage**: Gitaly persistence on `local-path` StorageClass (20Gi), PostgreSQL on `local-path` (10Gi), Redis (5Gi)
- **Disabled Components**: Registry, Pages, KAS, Runner, Minio (built-in), artifacts, LFS, packages, Terraform state, dependency proxy, toolbox
- **Databases**: Bundled PostgreSQL 14.8.0 and Redis 7.2.4

## Best Practices

### Security
- Configure HTTPS via cert-manager; the built-in NGINX ingress and certmanager are disabled in favor of the platform-wide instances
- Restrict SSH access through `gitlab-shell` with network policies if not required
- Rotate database credentials and store them in Kubernetes Secrets or an external secret manager

### Performance
- Webservice is limited to 1 replica with 2 worker processes -- scale `maxReplicas` if concurrent user load increases
- Sidekiq is a single replica; monitor queue depths via `/admin/background_jobs` and scale if jobs queue up
- Gitaly uses `local-path` storage; for production workloads consider migrating to Longhorn for replication

### Reliability
- PostgreSQL and Redis persistence are enabled; ensure regular backups via Velero
- Since artifacts, LFS, and packages are disabled, enable them with MinIO as the external object store if needed
- Monitor PostgreSQL metrics (enabled) to catch connection pool exhaustion early

## Configuration Reference

| Key | Current Value | Description |
|-----|---------------|-------------|
| `global.hosts.gitlab.name` | `gitlab.homelab.local` | GitLab web hostname |
| `global.edition` | `ce` | GitLab edition |
| `gitlab.webservice.resources.limits` | 2 CPU / 4Gi | Web server limits |
| `gitlab.sidekiq.resources.limits` | 1 CPU / 2Gi | Background job limits |
| `gitlab.gitaly.persistence.size` | `20Gi` | Git repository storage |
| `gitlab.gitaly.persistence.storageClass` | `local-path` | Storage class for Gitaly |
| `postgresql.primary.persistence.size` | `10Gi` | Database storage |
| `redis.master.persistence.size` | `5Gi` | Redis storage |

## Common Operations and Troubleshooting

```bash
# Check GitLab pod status
kubectl -n gitlab get pods

# View webservice logs
kubectl -n gitlab logs -l app=webservice -c webservice

# Check Sidekiq job processing
kubectl -n gitlab logs -l app=sidekiq

# Access Rails console (if toolbox is enabled)
kubectl -n gitlab exec -it deploy/gitlab-toolbox -- gitlab-rails console

# Check Gitaly disk usage
kubectl -n gitlab exec -it deploy/gitlab-gitaly-0 -- df -h /home/git/repositories

# Monitor PostgreSQL connections
kubectl -n gitlab exec -it gitlab-postgresql-0 -- psql -U gitlab -c "SELECT count(*) FROM pg_stat_activity;"

# Force GitLab reconfigure
kubectl -n gitlab delete pods -l app=webservice
```

## Official Documentation

- GitLab Helm Chart: https://docs.gitlab.com/charts/
- GitLab CE Administration: https://docs.gitlab.com/ee/administration/
- GitLab Minimal Deployment: https://docs.gitlab.com/charts/installation/deployment.html#deploy-with-minimal-resources
