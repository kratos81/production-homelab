# ===================================================================
# RKE2 Cluster 02 — 1 CP (12vCPU/48GB) + 4 Workers (8vCPU/32GB)
# IPs: 10.0.0.10 (CP), 10.0.0.11-14 (workers)
# Platform: VMware vSphere / vCenter
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
}

# -------------------------------------------------------------------
# Control Plane
# -------------------------------------------------------------------
resource "vsphere_virtual_machine" "c2_cp" {
  name             = "${local.c2_name}-cp-0"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.rke2.path
  num_cpus         = local.c2_cp_cpu
  memory           = local.c2_cp_memory
  guest_id         = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.disk_size
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    customize {
      linux_options {
        host_name = "${local.c2_name}-cp-0"
        domain    = "homelab.local"
      }
      network_interface {
        ipv4_address = local.c2_cp_ip
        ipv4_netmask = 24
      }
      ipv4_gateway    = "10.0.0.1"
      dns_server_list = ["10.0.0.1", "8.8.8.8"]
    }
  }

  extra_config = {
    "guestinfo.userdata"          = base64encode(templatefile("${path.module}/templates/cloud-init-cp.yaml.tpl", {
      rke2_version = var.kubernetes_version
      rke2_token   = var.rke2_token
      ssh_key      = var.ssh_public_key
    }))
    "guestinfo.userdata.encoding" = "base64"
  }

  lifecycle {
    ignore_changes = [extra_config]
  }
}

# -------------------------------------------------------------------
# Workers
# -------------------------------------------------------------------
resource "vsphere_virtual_machine" "c2_worker" {
  count            = local.c2_workers
  name             = "${local.c2_name}-worker-${count.index}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.rke2.path
  depends_on       = [vsphere_virtual_machine.c2_cp]
  num_cpus         = local.c2_worker_cpu
  memory           = local.c2_worker_memory
  guest_id         = data.vsphere_virtual_machine.template.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.worker_disk_size
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    customize {
      linux_options {
        host_name = "${local.c2_name}-worker-${count.index}"
        domain    = "homelab.local"
      }
      network_interface {
        ipv4_address = local.c2_worker_ips[count.index]
        ipv4_netmask = 24
      }
      ipv4_gateway    = "10.0.0.1"
      dns_server_list = ["10.0.0.1", "8.8.8.8"]
    }
  }

  extra_config = {
    "guestinfo.userdata"          = base64encode(templatefile("${path.module}/templates/cloud-init-worker.yaml.tpl", {
      rke2_version = var.kubernetes_version
      rke2_token   = var.rke2_token
      cp_address   = local.c2_cp_ip
      ssh_key      = var.ssh_public_key
    }))
    "guestinfo.userdata.encoding" = "base64"
  }

  lifecycle {
    ignore_changes = [extra_config]
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
