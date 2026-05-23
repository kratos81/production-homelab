# ===================================================================
# OKD 4.15 Cluster — 1 Bootstrap + 3 Masters (8vCPU/32GB) + 3 Workers (4vCPU/16GB)
# IPs: 10.0.0.130 (bootstrap), 10.0.0.131-133 (masters), 10.0.0.134-136 (workers)
# Domain: okd.homelab.local
# ===================================================================

locals {
  okd_name        = "okd"
  okd_bootstrap_ip = "10.0.0.130"
  okd_master_ips   = ["10.0.0.131", "10.0.0.132", "10.0.0.133"]
  okd_worker_ips   = ["10.0.0.134", "10.0.0.135", "10.0.0.136"]
  okd_master_cpu   = 8
  okd_master_mem   = "32768Mi"
  okd_worker_cpu   = 4
  okd_worker_mem   = "16384Mi"
  okd_boot_cpu     = 4
  okd_boot_mem     = "16384Mi"
  okd_master_disk  = "200Gi"
  okd_worker_disk  = "120Gi"
  okd_boot_disk    = "120Gi"
  okd_masters      = 3
  okd_workers      = 3
  # Ignition config server (runs on rke2-cluster-02 CP)
  okd_ign_server   = "http://10.0.0.10:8080"
}

# -------------------------------------------------------------------
# FCOS Image
# -------------------------------------------------------------------
resource "harvester_image" "fcos39" {
  name         = "fcos-39"
  namespace    = var.vm_namespace
  display_name = "Fedora CoreOS 39 (OKD 4.15)"
  source_type  = "download"
  url          = "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/39.20240210.3.0/x86_64/fedora-coreos-39.20240210.3.0-openstack.x86_64.qcow2.xz"

  timeouts {
    create = "30m"
    delete = "5m"
  }
}

# -------------------------------------------------------------------
# Bootstrap Node
# -------------------------------------------------------------------
resource "harvester_virtualmachine" "okd_bootstrap" {
  name      = "${local.okd_name}-bootstrap"
  namespace = var.vm_namespace

  cpu    = local.okd_boot_cpu
  memory = local.okd_boot_mem

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
    size       = local.okd_boot_disk
    bus        = "virtio"
    boot_order = 1
    image      = harvester_image.fcos39.id
  }

  cloudinit {
    user_data = <<-EOF
      {"ignition":{"config":{"replace":{"source":"${local.okd_ign_server}/bootstrap.ign"}},"version":"3.1.0"}}
    EOF
    network_data = templatefile("${path.module}/templates/network-config.yaml.tpl", {
      static_ip = local.okd_bootstrap_ip
    })
  }

  tags = {
    role    = "bootstrap"
    cluster = local.okd_name
  }
}

# -------------------------------------------------------------------
# Master Nodes
# -------------------------------------------------------------------
resource "harvester_virtualmachine" "okd_master" {
  count      = local.okd_masters
  name       = "${local.okd_name}-master-${count.index}"
  namespace  = var.vm_namespace

  cpu    = local.okd_master_cpu
  memory = local.okd_master_mem

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
    size       = local.okd_master_disk
    bus        = "virtio"
    boot_order = 1
    image      = harvester_image.fcos39.id
  }

  cloudinit {
    user_data = <<-EOF
      {"ignition":{"config":{"replace":{"source":"${local.okd_ign_server}/master.ign"}},"version":"3.1.0"}}
    EOF
    network_data = templatefile("${path.module}/templates/network-config.yaml.tpl", {
      static_ip = local.okd_master_ips[count.index]
    })
  }

  tags = {
    role    = "master"
    cluster = local.okd_name
  }
}

# -------------------------------------------------------------------
# Worker Nodes
# -------------------------------------------------------------------
resource "harvester_virtualmachine" "okd_worker" {
  count      = local.okd_workers
  name       = "${local.okd_name}-worker-${count.index}"
  namespace  = var.vm_namespace
  depends_on = [harvester_virtualmachine.okd_master]

  cpu    = local.okd_worker_cpu
  memory = local.okd_worker_mem

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
    size       = local.okd_worker_disk
    bus        = "virtio"
    boot_order = 1
    image      = harvester_image.fcos39.id
  }

  cloudinit {
    user_data = <<-EOF
      {"ignition":{"config":{"replace":{"source":"${local.okd_ign_server}/worker.ign"}},"version":"3.1.0"}}
    EOF
    network_data = templatefile("${path.module}/templates/network-config.yaml.tpl", {
      static_ip = local.okd_worker_ips[count.index]
    })
  }

  tags = {
    role    = "worker"
    cluster = local.okd_name
  }
}

# -------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------
output "okd_bootstrap_ip" {
  description = "OKD bootstrap node IP"
  value       = local.okd_bootstrap_ip
}

output "okd_master_ips" {
  description = "OKD master node IPs"
  value       = local.okd_master_ips
}

output "okd_worker_ips" {
  description = "OKD worker node IPs"
  value       = local.okd_worker_ips
}

output "okd_console_url" {
  description = "OKD web console URL"
  value       = "https://console-openshift-console.apps.okd.homelab.local"
}

output "okd_api_url" {
  description = "OKD API URL"
  value       = "https://api.okd.homelab.local:6443"
}
