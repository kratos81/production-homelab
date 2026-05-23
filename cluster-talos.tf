# ===================================================================
# Talos Linux Cluster — 1 CP (4vCPU/16GB) + 3 Workers (8vCPU/32GB)
# IPs: 10.0.0.21 (CP), 10.0.0.22-113 (workers)
# VIP: 10.0.0.20 (shared Kubernetes API endpoint)
# CNI: Cilium (Talos default CNI disabled)
# ===================================================================

locals {
  talos_name       = "talos-cluster"
  talos_vip        = "10.0.0.20"
  talos_cp_ip      = "10.0.0.21"
  talos_worker_ips = ["10.0.0.22", "10.0.0.23", "10.0.0.24"]
  talos_cp_cpu     = 4
  talos_cp_memory  = "16384Mi"
  talos_worker_cpu = 8
  talos_worker_mem = "32768Mi"
  talos_workers    = 3
  talos_disk_size  = "100Gi"
}

# -------------------------------------------------------------------
# Talos OS Image (nocloud, amd64)
# -------------------------------------------------------------------
resource "harvester_image" "talos" {
  name         = "talos-v1-7"
  namespace    = var.vm_namespace
  display_name = "Talos Linux v1.9 (nocloud amd64)"
  source_type  = "download"
  url          = "https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/v1.9.5/nocloud-amd64.qcow2"

  timeouts {
    create = "30m"
    delete = "5m"
  }
}

# -------------------------------------------------------------------
# Control Plane
# -------------------------------------------------------------------
resource "harvester_virtualmachine" "talos_cp" {
  name      = "${local.talos_name}-cp-0"
  namespace = var.vm_namespace

  cpu    = local.talos_cp_cpu
  memory = local.talos_cp_memory

  run_strategy = "RerunOnFailure"
  machine_type = "q35"

  network_interface {
    name           = "nic-0"
    network_name   = harvester_network.vm_lan.id
    type           = "bridge"
    wait_for_lease = false
  }

  disk {
    name       = "rootdisk"
    type       = "disk"
    size       = local.talos_disk_size
    bus        = "virtio"
    boot_order = 1
    image      = harvester_image.talos.id
  }

  tags = {
    role    = "control-plane"
    cluster = local.talos_name
  }
}

# -------------------------------------------------------------------
# Workers
# -------------------------------------------------------------------
resource "harvester_virtualmachine" "talos_worker" {
  count      = local.talos_workers
  name       = "${local.talos_name}-worker-${count.index}"
  namespace  = var.vm_namespace
  depends_on = [harvester_virtualmachine.talos_cp]

  cpu    = local.talos_worker_cpu
  memory = local.talos_worker_mem

  run_strategy = "RerunOnFailure"
  machine_type = "q35"

  network_interface {
    name           = "nic-0"
    network_name   = harvester_network.vm_lan.id
    type           = "bridge"
    wait_for_lease = false
  }

  disk {
    name       = "rootdisk"
    type       = "disk"
    size       = local.talos_disk_size
    bus        = "virtio"
    boot_order = 1
    image      = harvester_image.talos.id
  }

  tags = {
    role    = "worker"
    cluster = local.talos_name
  }
}

# -------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------
output "talos_cp_ip" {
  description = "Talos cluster control plane IP"
  value       = local.talos_cp_ip
}

output "talos_worker_ips" {
  description = "Talos cluster worker IPs"
  value       = local.talos_worker_ips
}

output "talos_vip" {
  description = "Talos cluster Kubernetes API VIP"
  value       = local.talos_vip
}

output "talos_endpoint" {
  description = "Talos cluster Kubernetes API endpoint"
  value       = "https://${local.talos_vip}:6443"
}

output "talos_provision_command" {
  description = "Run this to bootstrap the Talos cluster after VMs are created"
  value       = "./scripts/provision-talos.sh"
}
