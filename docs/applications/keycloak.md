# Keycloak - Identity Provider

## Overview

Keycloak provides centralized identity and access management (IAM) for this platform. It handles authentication via OpenID Connect (OIDC) and serves as the SSO provider for platform services such as ArgoCD. A custom realm (`homelab`) is pre-configured with clients, groups, and users via the Keycloak Config CLI.

## Architecture on This Platform

- **Deployment model**: Bitnami Helm chart v25.x deployed via ArgoCD (`sync-wave: 4`).
- **Namespace**: `keycloak`
- **Mode**: Production mode (`production: true`) with edge proxy termination (TLS terminated at ingress-nginx).
- **Database**: Embedded PostgreSQL with 5Gi persistent storage.
- **Ingress**: Exposed at `keycloak.homelab.local` via ingress-nginx with TLS from cert-manager (`homelab-ca-issuer`).
- **Realm configuration**: The `homelab` realm is bootstrapped via `keycloakConfigCli` with an ArgoCD OIDC client and an `admins` group.
- **Sync options**: `ServerSideApply=true` is enabled to handle large ConfigMaps in the realm configuration.
- **Retry policy**: Up to 3 retries with exponential backoff.

## Best Practices

### Security
- **CRITICAL**: Move all passwords and secrets out of values files and into a sealed-secrets or external-secrets solution (Vault). The current config contains plaintext credentials.
- Enforce `sslRequired: external` on all realms (currently set on the `homelab` realm).
- Disable self-registration (`registrationAllowed: false`) unless explicitly needed.
- Enable brute force protection (currently enabled: `bruteForceProtected: true`).
- Rotate client secrets periodically and use short-lived tokens.
- Use the `latest` PostgreSQL tag cautiously -- pin to a specific version for reproducibility.

### Performance
- Keycloak resources (500m/512Mi request, 1 CPU/1Gi limit) are appropriate for moderate user loads. Scale replicas for HA.
- PostgreSQL has its own resource allocation (250m/256Mi request). Monitor database performance for large user directories.
- Enable Keycloak caching and session clustering when running multiple replicas.

### Reliability
- The embedded PostgreSQL is a single point of failure. For production, consider an external managed database.
- Monitor Keycloak health endpoints via ingress.
- Back up the PostgreSQL database regularly -- realm configuration can be complex to recreate.

## Configuration Reference

### ArgoCD Application (`keycloak.yaml`)

| Setting | Value | Purpose |
|---|---|---|
| `chart` | `keycloak` (Bitnami) | Bitnami Keycloak chart |
| `targetRevision` | `25.*` | Pin to v25.x |
| `sync-wave` | `4` | Deploy after cert-manager/ingress |
| `ServerSideApply` | `true` | Handle large realm configs |

### Key Values (`keycloak-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `production` | `true` | Production-hardened mode |
| `proxy` | `edge` | TLS terminated at ingress |
| `proxyHeaders` | `xforwarded` | Trust X-Forwarded headers |
| `ingress.hostname` | `keycloak.homelab.local` | External hostname |
| `ingress.ingressClassName` | `nginx` | Use ingress-nginx |
| `postgresql.enabled` | `true` | Embedded PostgreSQL |
| `postgresql.primary.persistence.size` | `5Gi` | Database storage |
| `keycloakConfigCli.enabled` | `true` | Bootstrap realm config |
| `resources.requests.cpu` | `500m` | CPU request |
| `resources.limits.memory` | `1Gi` | Memory limit |

### Pre-configured Realm: `homelab`

- **Client**: `argocd` -- OIDC client for ArgoCD SSO with group membership mapper.
- **Group**: `admins` -- Admin group for RBAC mapping.
- **User**: Pre-configured admin user with group membership.

## Common Operations and Troubleshooting

| Task | Command |
|---|---|
| Check pods | `kubectl get pods -n keycloak` |
| View Keycloak logs | `kubectl logs -n keycloak -l app.kubernetes.io/name=keycloak` |
| Check PostgreSQL | `kubectl logs -n keycloak -l app.kubernetes.io/component=primary` |
| Access admin console | Browse to `https://keycloak.homelab.local/admin` |
| Re-run realm config | Delete the config-cli job, then ArgoCD sync |
| Force ArgoCD re-sync | `argocd app sync keycloak` |

**Common issues:**
- **Login redirect loop**: Verify `proxy: edge` and `proxyHeaders: xforwarded` are set. The ingress must pass X-Forwarded headers.
- **Config CLI job fails**: Check the realm JSON for syntax errors. View job logs with `kubectl logs -n keycloak job/<config-cli-job>`.
- **Database connection refused**: PostgreSQL pod may not be ready. Check PVC binding and pod events.
- **Certificate not trusted**: Clients must trust the self-signed CA. Distribute the CA cert or configure trust stores.

## Official Documentation

- Keycloak docs: <https://www.keycloak.org/documentation>
- Bitnami Helm chart: <https://github.com/bitnami/charts/tree/main/bitnami/keycloak>
- OIDC configuration: <https://www.keycloak.org/docs/latest/securing_apps/>
- Admin REST API: <https://www.keycloak.org/docs-api/latest/rest-api/>
