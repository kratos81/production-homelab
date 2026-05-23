# ===================================================================
# RKE2 Cluster 02 — 1 CP (12vCPU/48GB) + 4 Workers (8vCPU/32GB)
# IPs: 10.0.0.10 (CP), 10.0.0.11-107 (workers)
# CP is oversized to handle etcd + API server + 52 ArgoCD apps
# ===================================================================

locals {
  c2_name          = "rke2-cluster-02"
  c2_cp_ip         = "10.0.0.10"
  c2_worker_ips    = ["10.0.0.11", "10.0.0.12", "10.0.0.13", "10.0.0.14"]
  c2_cpu           = 12
  c2_memory        = "49152Mi"
  c2_worker_memory = "32768Mi"
  c2_workers       = 4
}

# -------------------------------------------------------------------
# Control Plane
# -------------------------------------------------------------------
resource "harvester_virtualmachine" "c2_cp" {
  name      = "${local.c2_name}-cp-0"
  namespace = var.vm_namespace

  cpu    = local.c2_cpu
  memory = local.c2_memory

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
    user_data = templatefile("${path.module}/templates/cloud-init-cp.yaml.tpl", {
      rke2_version = var.kubernetes_version
      rke2_token   = var.rke2_token
      ssh_key      = var.ssh_public_key
    })
    network_data = templatefile("${path.module}/templates/network-config.yaml.tpl", {
      static_ip = local.c2_cp_ip
    })
  }

  tags = {
    role    = "control-plane"
    cluster = local.c2_name
  }
}

# -------------------------------------------------------------------
# Workers
# -------------------------------------------------------------------
resource "harvester_virtualmachine" "c2_worker" {
  count      = local.c2_workers
  name       = "${local.c2_name}-worker-${count.index}"
  namespace  = var.vm_namespace
  depends_on = [harvester_virtualmachine.c2_cp]

  cpu    = local.c2_cpu
  memory = local.c2_worker_memory

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
    size       = var.worker_disk_size
    bus        = "virtio"
    boot_order = 1
    image      = harvester_image.ubuntu2204.id
  }

  cloudinit {
    user_data = templatefile("${path.module}/templates/cloud-init-worker.yaml.tpl", {
      rke2_version = var.kubernetes_version
      rke2_token   = var.rke2_token
      cp_address   = local.c2_cp_ip
      ssh_key      = var.ssh_public_key
    })
    network_data = templatefile("${path.module}/templates/network-config.yaml.tpl", {
      static_ip = local.c2_worker_ips[count.index]
    })
  }

  tags = {
    role    = "worker"
    cluster = local.c2_name
  }
}

# -------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------
output "c2_cp_ip" {
  description = "Cluster 02 control plane IP"
  value       = local.c2_cp_ip
}

output "c2_worker_ips" {
  description = "Cluster 02 worker IPs"
  value       = local.c2_worker_ips
}

output "c2_kubeconfig_command" {
  description = "Fetch kubeconfig for cluster 02"
  value       = "ssh -i ~/.ssh/id_rsa root@${local.c2_cp_ip} cat /etc/rancher/rke2/rke2.yaml"
}
