provider "harvester" {
  kubeconfig = "~/.kube/config"
}

resource "harvester_virtualmachine" "rke2_node" {
  count      = var.vm_count
  name       = "rke2-node-${count.index}"
  namespace  = var.namespace

  description = "RKE2 cluster node ${count.index}"
  tags = {
    role = count.index == 0 ? "master" : "worker"
  }

  network_interface {
    name         = "nic-0"
    type         = "bridge"
    network_name = var.network_name
  }

  disk {
    name       = "disk-0"
    type       = "disk"
    bus        = "virtio"
    image_name = var.image_name
  }

  ssh_keys = [var.ssh_key]

  cloudinit {
    user_data = count.index == 0 ?
      filebase64("${path.module}/cloudinit/master.yaml") :
      filebase64("${path.module}/cloudinit/worker.yaml")
  }

  cpu    = 2
  memory = 4096
}

