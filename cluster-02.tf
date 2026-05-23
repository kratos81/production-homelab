# ===================================================================
# RKE2 Cluster 02 — 1 CP (12vCPU/48GB) + 4 Workers (8vCPU/32GB)
# IPs: 10.0.0.10 (CP), 10.0.0.11-14 (workers)
# Platform: Proxmox VE
# ===================================================================

locals {
  c2_name          = "rke2-cluster-02"
  c2_cp_ip         = "10.0.0.10"
  c2_worker_ips    = ["10.0.0.11", "10.0.0.12", "10.0.0.13", "10.0.0.14"]
  c2_cp_cpu        = 12
  c2_cp_memory     = 49152
  c2_worker_cpu    = 8
  c2_worker_memory = 32768
  c2_workers       = 4
  c2_cp_vmid       = 200
  c2_worker_vmid   = 210
}

# -------------------------------------------------------------------
# Cloud-Init Snippets
# -------------------------------------------------------------------
resource "proxmox_virtual_environment_file" "cloud_init_cp" {
  content_type = "snippets"
  datastore_id = var.proxmox_iso_datastore
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/cloud-init-cp.yaml.tpl", {
      rke2_version = var.kubernetes_version
      rke2_token   = var.rke2_token
      ssh_key      = var.ssh_public_key
    })
    file_name = "${local.c2_name}-cp-cloud-init.yaml"
  }
}

resource "proxmox_virtual_environment_file" "cloud_init_worker" {
  count        = local.c2_workers
  content_type = "snippets"
  datastore_id = var.proxmox_iso_datastore
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/cloud-init-worker.yaml.tpl", {
      rke2_version = var.kubernetes_version
      rke2_token   = var.rke2_token
      cp_address   = local.c2_cp_ip
      ssh_key      = var.ssh_public_key
    })
    file_name = "${local.c2_name}-worker-${count.index}-cloud-init.yaml"
  }
}

# -------------------------------------------------------------------
# Control Plane
# -------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "c2_cp" {
  name      = "${local.c2_name}-cp-0"
  node_name = var.proxmox_node
  vm_id     = local.c2_cp_vmid

  cpu {
    cores = local.c2_cp_cpu
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = local.c2_cp_memory
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.proxmox_datastore
    file_id      = proxmox_virtual_environment_download_file.ubuntu2204.id
    interface    = "scsi0"
    size         = var.disk_size
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge  = var.proxmox_bridge
    vlan_id = var.proxmox_vlan_tag > 0 ? var.proxmox_vlan_tag : null
  }

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.c2_cp_ip}/24"
        gateway = "10.0.0.1"
      }
    }
    dns {
      servers = ["10.0.0.1", "8.8.8.8"]
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_cp.id
  }

  lifecycle {
    ignore_changes = [initialization]
  }
}

# -------------------------------------------------------------------
# Workers
# -------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "c2_worker" {
  count     = local.c2_workers
  name      = "${local.c2_name}-worker-${count.index}"
  node_name = var.proxmox_node
  vm_id     = local.c2_worker_vmid + count.index

  depends_on = [proxmox_virtual_environment_vm.c2_cp]

  cpu {
    cores = local.c2_worker_cpu
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = local.c2_worker_memory
  }

  agent {
    enabled = true
  }

  disk {
    datastore_id = var.proxmox_datastore
    file_id      = proxmox_virtual_environment_download_file.ubuntu2204.id
    interface    = "scsi0"
    size         = var.worker_disk_size
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge  = var.proxmox_bridge
    vlan_id = var.proxmox_vlan_tag > 0 ? var.proxmox_vlan_tag : null
  }

  operating_system {
    type = "l26"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${local.c2_worker_ips[count.index]}/24"
        gateway = "10.0.0.1"
      }
    }
    dns {
      servers = ["10.0.0.1", "8.8.8.8"]
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_worker[count.index].id
  }

  lifecycle {
    ignore_changes = [initialization]
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
