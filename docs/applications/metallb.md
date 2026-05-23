# MetalLB - L2 Load Balancer

## Overview

MetalLB provides bare-metal load balancer functionality for Kubernetes clusters that do not run on a cloud provider. In this platform, MetalLB operates in Layer 2 (ARP/NDP) mode to assign external IP addresses to `LoadBalancer`-type Services, enabling ingress traffic to reach workloads running on RKE2 on Proxmox VE.

## Architecture on This Platform

- **Deployment model**: Helm chart v0.14.x deployed via ArgoCD (`sync-wave: -3`, one of the first apps to deploy).
- **Namespace**: `metallb-system`
- **Mode**: Layer 2 advertisement -- the MetalLB speaker pods respond to ARP requests for allocated IPs on the local network segment.
- **Speaker tolerations**: Speakers tolerate `node-role.kubernetes.io/control-plane:NoSchedule`, ensuring they run on all nodes including control-plane nodes.
- **Consumers**: ingress-nginx controller Service, any other `LoadBalancer` Services.

## Best Practices

### Security
- Restrict the IP address pool to a dedicated, unused range on your network to avoid IP conflicts.
- Use `IPAddressPool` and `L2Advertisement` CRDs (v0.14+) instead of the legacy ConfigMap.
- Apply network policies to the `metallb-system` namespace to limit traffic to required ports only.

### Performance
- In L2 mode, all traffic for a given IP routes through a single leader node. For high-throughput workloads, consider the trade-off of single-node bottleneck.
- Keep the IP pool small and well-documented to simplify troubleshooting.

### Reliability
- Run speakers on all nodes (including control-plane) via tolerations to improve leader election resilience.
- ArgoCD `selfHeal: true` and `prune: true` ensure configuration drift is automatically corrected.
- Monitor speaker pod health -- if the leader node goes down, failover takes a few seconds while ARP caches expire.

## Configuration Reference

### ArgoCD Application (`metallb.yaml`)

| Setting | Value | Purpose |
|---|---|---|
| `chart` | `metallb` | Official MetalLB Helm chart |
| `targetRevision` | `0.14.*` | Pin to 0.14.x minor releases |
| `namespace` | `metallb-system` | Standard namespace |
| `sync-wave` | `-3` | Deploy early, before ingress |
| `selfHeal` | `true` | Auto-correct drift |
| `prune` | `true` | Remove orphaned resources |

### Values (`metallb-values.yaml`)

| Key | Value | Purpose |
|---|---|---|
| `speaker.tolerations` | control-plane NoSchedule | Run speakers on all nodes |

### Required CRDs (apply separately or via ArgoCD)

After MetalLB is installed, define `IPAddressPool` and `L2Advertisement` resources to allocate IPs.

## Common Operations and Troubleshooting

| Task | Command |
|---|---|
| Check speaker pods | `kubectl get pods -n metallb-system` |
| View allocated IPs | `kubectl get ipaddresspool -n metallb-system` |
| Check L2 advertisements | `kubectl get l2advertisement -n metallb-system` |
| View Service external IPs | `kubectl get svc -A --field-selector spec.type=LoadBalancer` |
| Debug speaker logs | `kubectl logs -n metallb-system -l app.kubernetes.io/component=speaker` |
| Force ArgoCD re-sync | `argocd app sync metallb` |

**Common issues:**
- **Service stuck in `<pending>`**: Verify an `IPAddressPool` exists and the pool has available addresses.
- **IP conflict on network**: Ensure the MetalLB pool range does not overlap with DHCP or other static assignments.
- **Failover delay**: L2 failover depends on ARP cache expiry (typically 2-5 seconds). This is expected behavior.

## Official Documentation

- MetalLB docs: <https://metallb.io/>
- Helm chart: <https://metallb.github.io/metallb/>
- L2 mode concepts: <https://metallb.io/concepts/layer2/>
- CRD reference: <https://metallb.io/configuration/>
