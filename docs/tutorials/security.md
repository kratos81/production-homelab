# Kubernetes Security -- Hands-On Tutorial

## Overview

This tutorial covers the security stack on this platform, teaching the 4C security model through hands-on exercises with Keycloak, Vault, NeuVector, Kyverno, and cert-manager.

**Prerequisites**: `kubectl` access, browser access to *.homelab.local services.

**Platform Tools Used**: Keycloak, Vault, NeuVector, Kyverno, cert-manager, Harbor/Trivy, Cosign

---

## 1. The 4C Security Model

```
┌─────────────────────────────────────────────┐
│                   Code                       │
│  (SAST, SCA, image signing, SBOM)           │
│  ┌─────────────────────────────────────┐    │
│  │             Container                │    │
│  │  (Image scanning, runtime security,  │    │
│  │   non-root, read-only rootfs)        │    │
│  │  ┌─────────────────────────────┐    │    │
│  │  │           Cluster            │    │    │
│  │  │  (RBAC, network policies,    │    │    │
│  │  │   admission control, secrets)│    │    │
│  │  │  ┌─────────────────────┐    │    │    │
│  │  │  │       Cloud          │    │    │    │
│  │  │  │  (Infrastructure,    │    │    │    │
│  │  │  │   node security)     │    │    │    │
│  │  │  └─────────────────────┘    │    │    │
│  │  └─────────────────────────────┘    │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

| Layer | Platform Tools |
|---|---|
| **Cloud** | VMware vSphere / vCenter, RKE2 hardened K8s, Cilium CNI |
| **Cluster** | Kyverno (admission), Vault (secrets), Keycloak (RBAC), cert-manager (TLS) |
| **Container** | NeuVector (runtime), Harbor/Trivy (scanning), Cosign (signing) |
| **Code** | Semgrep (SAST), Trivy (SCA), Cosign (SBOM) |

---

## 2. Identity and Access Management with Keycloak

### Accessing Keycloak

```bash
open https://keycloak.homelab.local
# Login: admin / CHANGE_ME_KEYCLOAK_ADMIN
```

### Exploring the Emagetech Realm

The platform comes with a pre-configured `homelab` realm:

1. Navigate to **Realm Settings** in the left sidebar
2. Check **Clients** -- `argocd` client is configured for OIDC
3. Check **Users** -- `user` user exists in the `/admins` group
4. Check **Groups** -- `/admins` group maps to ArgoCD admin role

### Hands-On: Create a New User

```bash
# Step 1: In Keycloak Admin Console
# Navigate to: homelab realm → Users → Add user

# Step 2: Fill in details
# Username: developer1
# Email: developer1@homelab.local
# First Name: Dev
# Last Name: User
# Enabled: ON

# Step 3: Set password
# Go to Credentials tab → Set Password
# Password: Developer2024!
# Temporary: OFF

# Step 4: Add to a group
# Go to Groups tab → Join Group → select "developers" (create it first if needed)
```

### OIDC Integration with ArgoCD

ArgoCD is configured to use Keycloak for SSO:

```bash
# Test SSO login
open https://argocd.homelab.local
# Click "Log in via Keycloak"
# Use: user / CHANGE_ME_USER_PASSWORD

# The user gets ArgoCD admin role because they're in the /admins group
```

### RBAC: Keycloak Groups to ArgoCD Roles

```yaml
# In argocd-values.yaml, the OIDC config maps groups:
server:
  config:
    oidc.config: |
      name: Keycloak
      issuer: https://keycloak.homelab.local/realms/homelab
      clientID: argocd
      clientSecret: argocd-keycloak-secret-2024
      requestedScopes: ["openid", "profile", "email", "groups"]

  rbacConfig:
    policy.csv: |
      g, /admins, role:admin      # Keycloak /admins group → ArgoCD admin
      g, /developers, role:readonly  # /developers group → read-only
```

---

## 3. Secrets Management with Vault

### Accessing Vault

```bash
open https://vault.homelab.local
# Method: Token
# Token: CHANGE_ME_VAULT_ROOT_TOKEN
```

### Unsealing Vault

Vault requires unsealing after pod restarts:

```bash
# Check seal status
kubectl exec -n vault vault-0 -- vault status

# If sealed, unseal with:
kubectl exec -n vault vault-0 -- vault operator unseal 8vju23VFephbzBBzogEQ5/6oJ/zqYtLWHkHs+aIniNM=
```

### Hands-On: KV v2 Secrets Engine

```bash
# Login via CLI
export VAULT_ADDR=https://vault.homelab.local
export VAULT_TOKEN=CHANGE_ME_VAULT_ROOT_TOKEN
export VAULT_SKIP_VERIFY=true

# Enable KV v2 secrets engine
vault secrets enable -path=secret kv-v2

# Store a secret
vault kv put secret/myapp/database \
  username="dbadmin" \
  password="SuperSecret123!" \
  host="postgres.default.svc.cluster.local"

# Read the secret
vault kv get secret/myapp/database

# Read specific field
vault kv get -field=password secret/myapp/database

# List secrets
vault kv list secret/myapp/

# Version history
vault kv metadata get secret/myapp/database
```

### Hands-On: Vault Kubernetes Auth

```bash
# Enable Kubernetes auth method
vault auth enable kubernetes

# Configure it to use the in-cluster service account
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443"

# Create a policy
vault policy write myapp-read - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
EOF

# Create a role that binds a K8s service account to the policy
vault write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp-sa \
  bound_service_account_namespaces=default \
  policies=myapp-read \
  ttl=1h

# Now pods with service account "myapp-sa" in "default" namespace
# can authenticate to Vault and read secrets from secret/myapp/*
```

---

## 4. Runtime Security with NeuVector

### Accessing NeuVector

```bash
open https://neuvector.homelab.local
# Login: admin / admin
```

### Dashboard Walkthrough

1. **Dashboard** -- Overview of security events, vulnerabilities, compliance
2. **Network Activity** -- Real-time network map of pod-to-pod communication
3. **Security Events** -- Process violations, network violations, file access alerts
4. **Policy** -- Network rules, process rules, response rules
5. **Assets** -- Container inventory with vulnerability scan results

### Hands-On: Process Profile Rules

Process rules define which processes are allowed to run inside containers:

```bash
# In NeuVector UI:
# 1. Go to Policy → Groups
# 2. Select a workload group (e.g., nv.sample-app.default)
# 3. Click on Process Profile Rules
# 4. View the auto-learned processes
# 5. Switch from "Discover" to "Monitor" mode
#    - Monitor: alerts on violations but doesn't block
# 6. Switch to "Protect" mode
#    - Protect: blocks unauthorized processes

# Test: exec into a pod and try running a command
kubectl exec -it -n sample-app deploy/sample-app -- sh
# In Protect mode, if "sh" isn't in the allowed list, NeuVector blocks it
```

### Hands-On: Network Rules

```bash
# In NeuVector UI:
# 1. Go to Policy → Network Rules
# 2. View auto-discovered network rules (Discover mode)
# 3. Add a custom rule:
#    From: nv.sample-app.default
#    To: External
#    Port: any
#    Action: Deny
#    (This blocks sample-app from making external calls)

# 4. Switch to Protect mode to enforce
```

### Compliance Scanning

```bash
# In NeuVector UI:
# 1. Go to Security Risks → Compliance
# 2. Run CIS Kubernetes Benchmark
# 3. Review findings:
#    - PASS: Compliant controls
#    - WARN: Recommendations
#    - FAIL: Items requiring attention
```

---

## 5. Policy Enforcement with Kyverno

Kyverno is a CNCF-graduated admission controller that enforces policies as Kubernetes resources.

### Viewing Existing Policies

```bash
# List all cluster policies
kubectl get clusterpolicies

# List namespace policies
kubectl get policies -A

# View policy details
kubectl get clusterpolicy <name> -o yaml
```

### Hands-On: Validate Policy (Require Labels)

```yaml
# Save as require-labels.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-app-label
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-app-label
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "The label 'app' is required on all Pods."
        pattern:
          metadata:
            labels:
              app: "?*"
```

```bash
# Apply the policy
kubectl apply -f require-labels.yaml

# Test: Try creating a pod without the label
kubectl run test-no-label --image=nginx
# Error: The label 'app' is required on all Pods.

# Test: Create with the label
kubectl run test-with-label --image=nginx --labels="app=test"
# Success

# Clean up
kubectl delete pod test-with-label
kubectl delete clusterpolicy require-app-label
```

### Hands-On: Mutate Policy (Add Default Labels)

```yaml
# Save as add-default-labels.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-labels
spec:
  rules:
    - name: add-team-label
      match:
        any:
          - resources:
              kinds:
                - Pod
      mutate:
        patchStrategicMerge:
          metadata:
            labels:
              managed-by: "kyverno"
              environment: "lab"
```

```bash
kubectl apply -f add-default-labels.yaml

# Create a pod and check labels
kubectl run test-mutate --image=nginx
kubectl get pod test-mutate --show-labels
# Labels include: managed-by=kyverno, environment=lab

# Clean up
kubectl delete pod test-mutate
kubectl delete clusterpolicy add-default-labels
```

### Hands-On: Block Privileged Containers

```yaml
# Save as block-privileged.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-privileged
spec:
  validationFailureAction: Enforce
  rules:
    - name: block-privileged-containers
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Privileged containers are not allowed."
        pattern:
          spec:
            containers:
              - securityContext:
                  privileged: "!true"
```

```bash
kubectl apply -f block-privileged.yaml

# Test: Try creating a privileged pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: privileged-test
spec:
  containers:
    - name: nginx
      image: nginx
      securityContext:
        privileged: true
EOF
# Error: Privileged containers are not allowed.

kubectl delete clusterpolicy block-privileged
```

### Policy Reports

```bash
# View policy report (non-enforced violations)
kubectl get policyreport -A
kubectl get clusterpolicyreport

# Detailed report
kubectl get policyreport -n default -o yaml
```

---

## 6. TLS and Certificate Management

### How cert-manager Works on This Platform

```
ClusterIssuer: selfsigned-bootstrap
        │
        ▼ (creates)
CA Certificate: homelab.local CA (RSA 4096)
        │
        ▼ (referenced by)
ClusterIssuer: homelab-ca-issuer
        │
        ▼ (issues certificates for)
All Ingress resources with annotation:
  cert-manager.io/cluster-issuer: homelab-ca-issuer
```

### Inspecting Certificates

```bash
# List all certificates
kubectl get certificates -A

# View a specific certificate
kubectl get certificate -n argocd argocd-tls -o yaml

# Check certificate details with openssl
kubectl get secret -n argocd argocd-tls -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -text -noout

# Check expiry
kubectl get secret -n argocd argocd-tls -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -enddate -noout

# List all cert-manager ClusterIssuers
kubectl get clusterissuers

# Check issuer status
kubectl describe clusterissuer homelab-ca-issuer
```

### Certificate Rotation

cert-manager automatically renews certificates before expiry (default: 30 days before). To force rotation:

```bash
# Delete the certificate secret (cert-manager will recreate it)
kubectl delete secret argocd-tls -n argocd

# Verify new certificate was issued
kubectl get certificate -n argocd argocd-tls
# READY should show True
```

---

## 7. Exercises

### Exercise 1: Create a Keycloak User with Limited Access

**Task**: Create a user `viewer1` in Keycloak, add them to a `viewers` group, and configure ArgoCD RBAC so they can only view (not modify) applications.

```bash
# Solution:
# 1. In Keycloak: Create user viewer1 with password
# 2. Create group "viewers" and add viewer1
# 3. In ArgoCD RBAC policy:
#    g, /viewers, role:readonly
# 4. Test: Login to ArgoCD via Keycloak as viewer1
#    - Should see apps but not be able to sync/delete
```

### Exercise 2: Vault Secret for an Application

**Task**: Store database credentials in Vault and demonstrate retrieving them from a pod.

```bash
# Store the secret
vault kv put secret/tutorial/db username="appuser" password="AppPass123!"

# Retrieve from CLI
vault kv get -field=password secret/tutorial/db

# For pod access, use the Kubernetes auth method from Section 3
```

### Exercise 3: Kyverno Policy Chain

**Task**: Create three policies: (1) require `app` label, (2) require resource limits, (3) block `latest` image tag. Test all three.

```yaml
# Policy 3: Block latest tag
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-latest-tag
spec:
  validationFailureAction: Enforce
  rules:
    - name: block-latest
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Using 'latest' image tag is not allowed. Specify a version."
        pattern:
          spec:
            containers:
              - image: "!*:latest & !*:*"
```

### Exercise 4: NeuVector Network Segmentation

**Task**: Using NeuVector, create a network rule that only allows the sample-app to communicate with its own namespace and the monitoring namespace. Block all other network traffic.

### Exercise 5: Certificate Inspection Audit

**Task**: List all TLS certificates on the cluster, check which ones expire within 30 days, and verify the issuer chain.

```bash
# List all certs with expiry
for ns in $(kubectl get certificates -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\n"}{end}' | sort -u); do
  echo "=== $ns ==="
  kubectl get certificates -n $ns -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status,EXPIRY:.status.notAfter
done
```

---

## 8. Security Hardening Checklist

| Category | Check | Status |
|---|---|---|
| **Identity** | SSO enabled for all admin UIs | Keycloak → ArgoCD |
| **Identity** | Default passwords changed | Check all services |
| **Secrets** | No plaintext secrets in Git | Use Vault or SealedSecrets |
| **Secrets** | Vault is sealed after restart | Manual unseal required |
| **Admission** | Kyverno blocks privileged pods | Policy in Enforce mode |
| **Admission** | Kyverno requires resource limits | Policy in Enforce mode |
| **Runtime** | NeuVector in Monitor/Protect mode | Check Security Events |
| **Network** | Network policies enforced | Cilium CNI + NeuVector |
| **Images** | All images scanned by Trivy | Harbor auto-scan enabled |
| **Images** | Images signed with Cosign | Verify in CI pipeline |
| **TLS** | All ingresses use HTTPS | cert-manager auto-issues |
| **TLS** | Certificates auto-renew | cert-manager handles this |
| **RBAC** | Least-privilege access | Keycloak groups → K8s roles |
| **Audit** | Kubernetes audit logging | RKE2 default audit policy |
| **Backup** | Secrets backed up | Velero daily backup |

---

## Next Steps

- [DevSecOps Tutorial](devsecops.md) -- Integrate security into CI/CD pipelines
- [Monitoring & Alerting Tutorial](monitoring-and-alerting.md) -- Alert on security events
- [GitOps Tutorial](gitops.md) -- Manage security policies through Git
