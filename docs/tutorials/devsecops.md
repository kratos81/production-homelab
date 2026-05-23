# DevSecOps Comprehensive Tutorial

## Introduction to DevSecOps

DevSecOps is the practice of integrating security throughout the entire software development lifecycle. Rather than treating security as an afterthought, DevSecOps implements "shift-left" security—moving security checks earlier in the pipeline to catch vulnerabilities at development time rather than in production.

### Core Principles

1. **Security as Code**: Define policies and controls in code, making them auditable and versionable
2. **Automation**: Automate security scanning, validation, and remediation to reduce manual bottlenecks
3. **Continuous Assessment**: Security is not a phase but a continuous practice throughout the pipeline
4. **Supply Chain Protection**: Verify provenance, sign artifacts, and validate dependencies
5. **Runtime Enforcement**: Monitor and enforce security policies even after deployment

---

## Understanding Our CI/CD Pipeline Architecture

Our DevSecOps platform uses a comprehensive pipeline with multiple security gates:

```
Build (Kaniko)
    ↓
Scan (Trivy SCA + Semgrep SAST) [Parallel]
    ↓
Sign (Cosign)
    ↓
Deploy (GitOps)
    ↓
DAST
    ↓
Metrics & Monitoring
```

Each stage includes specific security controls that prevent vulnerable code and images from progressing further.

---

## Section 1: Kyverno - Policy-as-Code Admission Control

### What is Kyverno?

Kyverno is a Kubernetes-native policy engine that enforces security policies at admission time. Policies are defined in Kubernetes resources (YAML), making them version-controlled and auditable.

### Exercise 1: Deploying and Writing Kyverno Policies

#### Step 1: Access the Kyverno Dashboard

```bash
kubectl port-forward -n kyverno svc/kyverno 8080:8080
# Access: http://localhost:8080
```

#### Step 2: Create a Policy Requiring Labels

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-security-labels
spec:
  validationFailureAction: audit  # Set to 'enforce' for production
  rules:
  - name: check-security-labels
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Security labels are required"
      pattern:
        metadata:
          labels:
            security-scanned: "true"
            vulnerability-signed: "true"
```

Apply this policy:

```bash
kubectl apply -f require-security-labels.yaml
```

#### Step 3: Create a Policy Blocking Privileged Containers

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-privileged-containers
spec:
  validationFailureAction: enforce
  rules:
  - name: privileged-containers
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Privileged containers are not allowed"
      pattern:
        spec:
          containers:
          - securityContext:
              privileged: false
```

#### Step 4: Create a Policy Requiring Resource Limits

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: enforce
  rules:
  - name: cpu-and-memory-limits
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "CPU and memory limits are required"
      pattern:
        spec:
          containers:
          - resources:
              limits:
                memory: "?*"
                cpu: "?*"
```

#### Step 5: Create a Policy Requiring Non-Root Users

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-non-root-user
spec:
  validationFailureAction: enforce
  rules:
  - name: check-non-root
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Containers must run as non-root"
      pattern:
        spec:
          containers:
          - securityContext:
              runAsNonRoot: true
```

### Testing Your Policies

```bash
# This should fail (no labels)
kubectl run test-pod --image=nginx

# This should succeed (has required labels)
kubectl run secure-pod --image=nginx \
  --labels=security-scanned=true,vulnerability-signed=true

# Verify policy violations
kubectl get clusterpolicies
kubectl get policyreport -A
```

---

## Section 2: Image Scanning with Trivy

### What is Trivy?

Trivy is a vulnerability scanner that detects CVEs in container images, filesystems, and Git repositories. It scans both the operating system packages and application dependencies.

### Exercise 2: Scanning Images Locally with Trivy

#### Step 1: Install and Configure Trivy

```bash
# On macOS
brew install aquasecurity/trivy/trivy

# Verify installation
trivy version
```

#### Step 2: Scan a Local Image

```bash
# Scan an image from the command line
trivy image --severity HIGH,CRITICAL nginx:latest

# Generate a JSON report
trivy image --format json --output trivy-report.json nginx:latest

# Scan with vulnerability database cache
trivy image --severity HIGH,CRITICAL \
  --skip-update \
  nginx:latest
```

#### Step 3: Scan a Custom Application Image

```bash
# Build your application Dockerfile
cat > Dockerfile << 'EOF'
FROM node:16-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
EOF

# Build the image
docker build -t my-app:v1 .

# Scan it
trivy image --severity HIGH,CRITICAL my-app:v1
```

### Exercise 3: Harbor Auto-Scan Integration

#### Step 1: Access Harbor Registry

```bash
# Harbor URL: https://harbor.homelab.local
# Username: admin
# Password: CHANGE_ME_HARBOR_ADMIN

# Login via Docker CLI
docker login harbor.homelab.local
# Use admin / CHANGE_ME_HARBOR_ADMIN
```

#### Step 2: Push Image to Harbor

```bash
# Tag your image
docker tag my-app:v1 harbor.homelab.local/library/my-app:v1

# Push to Harbor
docker push harbor.homelab.local/library/my-app:v1

# Vulnerability scanning starts automatically
# Check results in Harbor UI under: Projects > library > Repositories > my-app
```

#### Step 3: Configure Scan Policy

In Harbor UI:
1. Navigate to Projects > library
2. Select the repository
3. View vulnerability scan results
4. Enable "Prevent vulnerable images from being pulled" in project settings

---

## Section 3: SAST with Semgrep

### What is Semgrep?

Semgrep is a static analysis tool that finds bugs, security issues, and anti-patterns in source code. It uses YAML rules that are easy to understand and customize.

### Exercise 4: Running Semgrep Locally

#### Step 1: Install Semgrep

```bash
# On macOS
brew install semgrep

# Verify installation
semgrep --version
```

#### Step 2: Scan Your Codebase

```bash
# Run default rules against your repo
semgrep --config=p/owasp-top-ten .

# Show only high-confidence findings
semgrep --config=p/security-audit --json > semgrep-report.json

# Scan specific languages
semgrep --config=p/python .
```

#### Step 3: Create a Custom Semgrep Rule

```bash
cat > my-rule.yaml << 'EOF'
rules:
- id: insecure-hardcoded-secret
  pattern: |
    password = "..."
  message: "Hardcoded password detected"
  severity: ERROR
  languages: [python]
EOF

# Test your rule
semgrep --config=my-rule.yaml .
```

#### Step 4: Integrate Semgrep in GitLab CI

This integrates directly into your GitLab pipeline (see Section 8 for full CI/CD setup).

---

## Section 4: Image Signing with Cosign

### What is Cosign?

Cosign provides container image signing and verification, creating a cryptographic proof that an image has been vetted and hasn't been tampered with.

### Exercise 5: Sign and Verify Container Images

#### Step 1: Generate Cosign Keys

```bash
# Generate a key pair (set a passphrase when prompted)
cosign generate-key-pair

# Keys are stored as:
# - cosign.key (private)
# - cosign.pub (public)
```

#### Step 2: Sign an Image

```bash
# Sign the image in Harbor
cosign sign --key cosign.key \
  harbor.homelab.local/library/my-app:v1

# Enter your passphrase when prompted
```

#### Step 3: Verify the Signature

```bash
# Verify signature using the public key
cosign verify --key cosign.pub \
  harbor.homelab.local/library/my-app:v1

# Check signature details in Harbor UI:
# Repository > Image Details > Signatures tab
```

#### Step 4: Attach SBOM (Software Bill of Materials)

```bash
# Generate SBOM using Syft
syft harbor.homelab.local/library/my-app:v1 -o spdx > sbom.json

# Attach SBOM to image
cosign attach sbom --sbom sbom.json \
  harbor.homelab.local/library/my-app:v1

# Verify SBOM attachment
cosign download sbom harbor.homelab.local/library/my-app:v1
```

---

## Section 5: Runtime Security with NeuVector

### What is NeuVector?

NeuVector is a runtime container security platform that monitors processes, network traffic, and syscalls to detect threats and enforce security policies during container execution.

### Accessing NeuVector Dashboard

```bash
# URL: https://neuvector.homelab.local
# Username: admin
# Password: admin
```

### Creating Process Rules

In NeuVector Dashboard:

1. Navigate to Policy > Process Rules
2. Click "Create Process Rule"
3. Configure:
   - **Allowed Processes**: Add legitimate processes (e.g., nginx, node, python)
   - **Denied Processes**: Block suspicious processes (e.g., nc, bash, sh)
   - **Process Path**: Specify full path to process
4. Apply to specific container groups

### Creating Network Rules

In NeuVector Dashboard:

1. Navigate to Policy > Network Rules
2. Click "Add Network Rule"
3. Configure:
   - **Source**: Container or service
   - **Destination**: Target service or IP
   - **Port**: Specific ports (e.g., 443, 8080)
   - **Protocol**: TCP/UDP
4. Deny all traffic not explicitly allowed (default-deny)

### Example Configuration

```yaml
# Network rule denying outbound to suspicious ports
From: namespace:default
To: external
Port: 4444,5555,6666
Protocol: TCP
Action: Deny
Reason: Suspicious external communication
```

---

## Section 6: Building a Secure GitLab CI Pipeline

### Exercise: Create a Complete Secure Pipeline

Create a `.gitlab-ci.yml` in your repository:

```yaml
variables:
  REGISTRY: harbor.homelab.local
  PROJECT_NAME: my-secure-app

stages:
  - build
  - scan
  - sign
  - deploy

build:
  stage: build
  image: gcr.io/kaniko-project/executor:latest
  script:
    - echo "{\"auths\":{\"harbor.homelab.local\":{\"username\":\"$HARBOR_USER\",\"password\":\"$HARBOR_PASS\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile $CI_PROJECT_DIR/Dockerfile
      --destination $REGISTRY/library/$PROJECT_NAME:$CI_COMMIT_SHA
      --cache=true
      --cache-repo=$REGISTRY/library/$PROJECT_NAME:cache
  only:
    - merge_requests
    - main

trivy_scan:
  stage: scan
  image: aquasec/trivy:latest
  script:
    - trivy image --severity HIGH,CRITICAL
      --exit-code 1
      $REGISTRY/library/$PROJECT_NAME:$CI_COMMIT_SHA
  allow_failure: false

semgrep_scan:
  stage: scan
  image: returntocorp/semgrep
  script:
    - semgrep --config=p/owasp-top-ten --json --output=semgrep-report.json .
  artifacts:
    reports:
      sast: semgrep-report.json
  allow_failure: true

sign_image:
  stage: sign
  image: gcr.io/projectsigstore/cosign:latest
  script:
    - cosign sign --key $COSIGN_KEY
      $REGISTRY/library/$PROJECT_NAME:$CI_COMMIT_SHA
  only:
    - main

deploy:
  stage: deploy
  image: alpine/helm:latest
  script:
    - helm repo add myrepo $HELM_REPO
    - helm upgrade --install $PROJECT_NAME myrepo/$PROJECT_NAME
      --set image.tag=$CI_COMMIT_SHA
  only:
    - main
```

### GitLab CI Variables Setup

In GitLab (Settings > CI/CD > Variables):

```
HARBOR_USER: admin
HARBOR_PASS: CHANGE_ME_HARBOR_ADMIN
COSIGN_KEY: [base64 encoded cosign.key]
GITLAB_RUNNER_TOKEN: [your runner token]
```

---

## Section 7: Supply Chain Security End-to-End Walkthrough

### Complete Workflow Example

```bash
# 1. Developer commits code with security fixes
git commit -m "Fix: SQL injection in login endpoint"
git push origin feature/security-fix

# 2. GitLab CI pipeline triggers
# - Builds image with Kaniko
# - Scans with Trivy (detects CVEs)
# - Analyzes with Semgrep (finds code issues)
# - Both must pass before proceeding

# 3. Image is signed with Cosign
# - Cryptographic signature attached
# - SBOM generated and attached

# 4. Kyverno admission controller validates
# - Image must be signed
# - Labels must be present
# - Resource limits must be defined

# 5. Deployment proceeds
# - NeuVector runtime policies enforce
# - Network rules restrict traffic
# - Process rules monitor execution

# 6. Metrics collected
# - Vulnerability trends tracked
# - Policy violations reported
# - Audit logs maintained
```

---

## Common DevSecOps Pitfalls and Best Practices

### Pitfalls to Avoid

1. **Scanning Only on Merge Requests**: Scan on every commit for faster feedback
2. **Ignoring SBOM Data**: Track all dependencies for compliance and incident response
3. **Weak Key Management**: Rotate signing keys regularly, use secrets management
4. **Policy Alert Fatigue**: Start with audit mode, gradually enforce based on your risk profile
5. **Skipping Manual Security Reviews**: Automation complements but doesn't replace human review

### Best Practices

1. **Default-Deny Posture**: Block all traffic/processes by default, whitelist what you need
2. **Immutable Images**: Never modify running containers, always redeploy with new builds
3. **Namespace Isolation**: Use Kubernetes network policies alongside Kyverno
4. **Audit Everything**: Enable audit logging for all policy violations and deployments
5. **Regular Policy Updates**: Review and update policies quarterly based on new threats
6. **Test Policies Thoroughly**: Use audit mode before enforcing to understand impact

---

## Exercise Solutions

### Solution 1: Kyverno Policy Verification

```bash
# View all active policies
kubectl get clusterpolicies -o wide

# Check policy violations
kubectl get policyreport -A

# View detailed violation for a specific policy
kubectl describe policyreport -n kyverno-monitoring
```

### Solution 2: Trivy Report Analysis

```bash
# Generate severity breakdown
trivy image --format table nginx:latest | grep -E "CRITICAL|HIGH"

# Export for compliance
trivy image --format sarif nginx:latest > trivy-sarif.json
```

### Solution 3: Semgrep Integration Verification

```bash
# Run with specific severity
semgrep --config=p/security-audit --json . | jq '.results[] | select(.extra.severity=="ERROR")'
```

### Solution 4: Cosign Verification in Pipeline

```bash
# Verify in CI script
cosign verify --key cosign.pub $IMAGE_URL || exit 1
```

### Solution 5: NeuVector Policy Simulation

```bash
# Export all rules for backup
# In NeuVector UI: Administration > Configuration > Backup

# Test policy impact before enforcement
# Enable audit mode for 24 hours, analyze violations, then enforce
```

---

## Conclusion

This DevSecOps platform provides defense-in-depth security across the entire container lifecycle. By implementing these controls and best practices, you create an environment where security is integrated into every stage of development and deployment.

Remember: Security is not a destination but a continuous journey of improvement.
