# ===================================================================
# Rancher Management Cluster — Single-Node (4vCPU/16GB)
# IP: 10.0.0.50 — Manages workload clusters via Rancher UI
# ===================================================================

locals {
  rancher_name   = "rancher-mgmt"
  rancher_ip     = "10.0.0.50"
  rancher_cpu    = 4
  rancher_memory = "16384Mi"
}

# -------------------------------------------------------------------
# Rancher Management Server (single-node RKE2)
# -------------------------------------------------------------------
resource "harvester_virtualmachine" "rancher" {
  name      = "${local.rancher_name}-0"
  namespace = var.vm_namespace

  cpu    = local.rancher_cpu
  memory = local.rancher_memory

  run_strategy = "RerunOnFailure"
  machine_type = "q35"

  network_interface {
    name           = "nic-0"
    network_name   = harvester_network.vm_lan.id
    type           = "bridge"
    wait_for_lease = true
  }

  disk {
    name       = "rootdisk"
    type       = "disk"
    size       = var.disk_size
    bus        = "virtio"
    boot_order = 1
    image      = harvester_image.ubuntu2204.id
  }

  cloudinit {
    user_data = templatefile("${path.module}/templates/cloud-init-rancher.yaml.tpl", {
      rke2_version = var.kubernetes_version
      rke2_token   = var.rke2_token
      ssh_key      = var.ssh_public_key
    })
    network_data = templatefile("${path.module}/templates/network-config.yaml.tpl", {
      static_ip = local.rancher_ip
    })
  }

  tags = {
    role    = "rancher-management"
    cluster = local.rancher_name
  }
}

# -------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------
output "rancher_ip" {
  description = "Rancher management server IP"
  value       = local.rancher_ip
}

output "rancher_kubeconfig_command" {
  description = "Fetch kubeconfig for Rancher management cluster"
  value       = "ssh -i ~/.ssh/id_rsa root@${local.rancher_ip} cat /etc/rancher/rke2/rke2.yaml"
}
