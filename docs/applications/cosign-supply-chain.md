# Cosign + Kyverno - Supply Chain Security

## Overview

This component implements supply chain security using Cosign (from the Sigstore project) for container image signing and Kyverno ClusterPolicies for admission-time verification. Three policies enforce trusted registries, image signature verification, and SLSA provenance attestations. All policies are deployed in **Audit mode** by default, logging violations without blocking workloads, allowing you to assess impact before switching to enforcement.

## Architecture on This Platform

- **Deployment model**: Raw Kubernetes manifests (Kyverno ClusterPolicies) deployed via ArgoCD (sync-wave 14).
- **Namespace**: `kyverno` (policies are cluster-scoped).
- **Dependencies**: Requires Kyverno admission controller to be running (sync-wave 9).
- **Manifests**: `application/values/cosign-verify/image-verification-policy.yaml`

## Policies

### 1. verify-harbor-image-signatures

Verifies that container images pulled from `harbor.homelab.local` are signed using Cosign keyless signing with the Sigstore public transparency log (Rekor).

| Field | Value |
|---|---|
| **Scope** | All Pods with images from `harbor.homelab.local/*` |
| **Mode** | Audit (violations logged, not blocked) |
| **Verification** | Cosign keyless via Rekor (`rekor.sigstore.dev`) |
| **Mutation** | `mutateDigest: true` -- rewrites tags to digests for immutability |

### 2. restrict-image-registries

Enforces an allowlist of trusted container registries. Any image from an unlisted registry triggers an audit violation.

| Field | Value |
|---|---|
| **Scope** | All Pods (init containers and containers) |
| **Mode** | Audit |
| **Allowed Registries** | `harbor.homelab.local`, `docker.io`, `ghcr.io`, `gcr.io`, `quay.io`, `registry.k8s.io`, `public.ecr.aws`, `litmuschaos`, `litmuschaos.docker.scarf.sh` |

### 3. require-image-provenance

Checks that Deployments and StatefulSets in the `sample-app` namespace have SLSA build provenance annotations (`slsa.dev/buildType`).

| Field | Value |
|---|---|
| **Scope** | Deployments and StatefulSets in `sample-app` namespace |
| **Mode** | Audit |
| **Required Annotation** | `slsa.dev/buildType: *` |

## Signing Images in GitLab CI

Add this stage to your `.gitlab-ci.yml` to sign images with Cosign keyless signing:

```yaml
sign-image:
  stage: sign
  image: bitnami/cosign:latest
  script:
    - cosign sign --yes
        --rekor-url https://rekor.sigstore.dev
        ${HARBOR_REGISTRY}/${CI_PROJECT_PATH}:${CI_COMMIT_SHA}
  variables:
    COSIGN_EXPERIMENTAL: "1"
```

For SLSA provenance, add an annotation to your deployment manifest:

```yaml
metadata:
  annotations:
    slsa.dev/buildType: "https://gitlab.com/pipeline"
    slsa.dev/builder: "gitlab-runner"
    slsa.dev/commit: "${CI_COMMIT_SHA}"
```

## Switching from Audit to Enforce

To start blocking non-compliant workloads:

1. Review current violations:
   ```bash
   kubectl get policyreport -A
   kubectl get clusterpolicyreport
   ```

2. Ensure all legitimate workloads are compliant (signed images, trusted registries).

3. Edit the policy YAML and change:
   ```yaml
   validationFailureAction: Audit
   ```
   to:
   ```yaml
   validationFailureAction: Enforce
   ```

4. Commit and push -- ArgoCD will sync the change.

**Warning**: Switching to Enforce mode will block any Pod that violates the policy. Test thoroughly in Audit mode first.

## Best Practices

### Security
- Enable `mutateDigest: true` on image verification policies to prevent tag mutation attacks (where a tag is re-pushed with different content).
- Sign all images in your CI pipeline, not just production images, to build a consistent signing practice.
- Use the trusted registry allowlist to prevent shadow IT container deployments.
- Periodically review PolicyReports for violations that might indicate supply chain compromise.

### Performance
- Image verification adds latency to Pod admission (typically 100-500ms per image check). This is negligible for most workloads.
- The `background: true` setting ensures existing resources are also audited, not just new admissions.
- Set `required: false` on image verification initially to avoid blocking pods when Rekor is temporarily unavailable.

### Reliability
- Keep policies in Audit mode until you have full CI/CD signing coverage.
- The `required: false` flag on the signature verification means unsigned images are allowed (just flagged) -- set to `true` only when ready to enforce.
- If Kyverno is down, the `failurePolicy` determines whether pods are admitted or blocked. Default is `Fail` -- consider `Ignore` for non-critical policies.

## Configuration Reference

### Policies (`cosign-verify/image-verification-policy.yaml`)

| Policy | Type | Mode | Scope |
|---|---|---|---|
| `verify-harbor-image-signatures` | Image Verification | Audit | All Pods with harbor.homelab.local images |
| `restrict-image-registries` | Validation | Audit | All Pods |
| `require-image-provenance` | Validation | Audit | Deployments/StatefulSets in sample-app |

## Useful Commands

| Task | Command |
|---|---|
| List policies | `kubectl get clusterpolicy` |
| View policy details | `kubectl describe clusterpolicy verify-harbor-image-signatures` |
| Check violations (namespaced) | `kubectl get policyreport -A` |
| Check violations (cluster-wide) | `kubectl get clusterpolicyreport` |
| View specific violations | `kubectl describe policyreport -n <namespace>` |
| Test policy against a manifest | `kubectl apply --dry-run=server -f deployment.yaml` |

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Policies not applying | Kyverno admission controller not running | Check `kubectl get pods -n kyverno` |
| No PolicyReports generated | Background scan not completed | Wait for Kyverno background controller to process existing resources |
| False positives on registry check | Image uses a short name without registry prefix | Use fully qualified image names (e.g., `docker.io/library/nginx` not just `nginx`) |
| Signature verification timeout | Rekor transparency log unreachable | Check network connectivity to `rekor.sigstore.dev`; consider `required: false` |

## Related Components

- **Kyverno** -- Policy engine that executes these ClusterPolicies as admission webhooks.
- **Harbor** -- Private container registry; images pushed here should be signed with Cosign.
- **GitLab CI** -- Pipeline where Cosign signing and SLSA provenance annotation happen.
- **Tetragon** -- Provides runtime security monitoring after images are admitted.
- **NeuVector** -- Complements admission-time policies with runtime container firewalling.
