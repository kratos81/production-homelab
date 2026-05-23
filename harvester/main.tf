terraform {
  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = "~> 0.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

variable "harvester_kubeconfig" {
  description = "Path to Harvester kubeconfig file"
  type        = string
  default     = "~/.kube/harvester-config"
}

variable "worker_count" {
  description = "Number of worker nodes per cluster"
  type        = number
  default     = 6
}

variable "memory" {
  description = "Memory allocation per node"
  type        = string
  default     = "20Gi"
}

variable "cpu" {
  description = "CPU allocation per node"
  type        = number
  default     = 6
}

variable "network_name" {
  description = "Harvester network name"
  type        = string
  default     = "lan-network"
}

variable "namespace" {
  description = "Kubernetes namespace for VMs"
  type        = string
  default     = "default"
}

variable "image_name" {
  description = "VM image template name"
  type        = string
  default     = "templateversion-default-z6nd7-image-0"
}

provider "harvester" {
  kubeconfig = var.harvester_kubeconfig
}

locals {
  dev_master_ip      = "10.0.0.40"
  dev_worker_ips     = ["10.0.0.41", "10.0.0.42", "10.0.0.43", "10.0.0.44", "10.0.0.45", "10.0.0.46"]
  sandbox_master_ip  = "10.0.0.60"
  sandbox_worker_ips = ["10.0.0.61", "10.0.0.62", "10.0.0.63", "10.0.0.64", "10.0.0.65", "10.0.0.66"]
}

# Sample resource block for dev master VM
resource "null_resource" "dev_master" {
  provisioner "local-exec" {
    command = <<EOT
cat <<EOF | kubectl --kubeconfig ${var.harvester_kubeconfig} apply -f -
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: dev-master
  namespace: ${var.namespace}
spec:
  running: true
  template:
    metadata:
      labels:
        harvesterhci.io/vmName: dev-master
    spec:
      domain:
        cpu:
          cores: ${var.cpu}
        devices:
          disks:
            - disk:
                bus: virtio
              name: disk-0
              bootOrder: 1
            - disk:
                bus: virtio
              name: cloudinitdisk
          interfaces:
            - masquerade: {}
              name: default
            - bridge: {}
              name: nic-1
        resources:
          requests:
            memory: ${var.memory}
      networks:
        - name: default
          pod: {}
        - multus:
            networkName: ${var.namespace}/${var.network_name}
          name: nic-1
      volumes:
        - name: disk-0
          containerDisk:
            image: ${var.namespace}/${var.image_name}
        - name: cloudinitdisk
          cloudInitNoCloud:
            networkData: |
              version: 2
              ethernets:
                eth0:
  match:
    name: en*
                  dhcp4: false
                  addresses: ["${local.dev_master_ip}/24"]
                  gateway4: "10.0.0.1"
                  nameservers:
                    addresses: ["8.8.8.8", "1.1.1.1"]
            userData: |
              #cloud-config
              package_update: true
              packages:
                - qemu-guest-agent
              write_files:
                - path: /etc/rancher/rke2/config.yaml
                  content: |
                    bind-address: ${local.dev_master_ip}
                    advertise-address: ${local.dev_master_ip}
                    tls-san:
                      - ${local.dev_master_ip}
                  permissions: '0644'
              runcmd:
                - systemctl enable --now qemu-guest-agent.service
                - hostnamectl set-hostname dev-master
                - curl -sfL https://get.rke2.io | sh -
                - systemctl enable rke2-server.service
                - systemctl start rke2-server.service
EOF
EOT
  }
}

resource "null_resource" "dev_workers" {
  count = var.worker_count

  provisioner "local-exec" {
    command = <<EOT
cat <<EOF | kubectl --kubeconfig ${var.harvester_kubeconfig} apply -f -
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: dev-worker-${count.index + 1}
  namespace: ${var.namespace}
spec:
  running: true
  template:
    metadata:
      labels:
        harvesterhci.io/vmName: dev-worker-${count.index + 1}
    spec:
      domain:
        cpu:
          cores: ${var.cpu}
        devices:
          disks:
            - disk:
                bus: virtio
              name: disk-0
              bootOrder: 1
            - disk:
                bus: virtio
              name: cloudinitdisk
          interfaces:
            - masquerade: {}
              name: default
            - bridge: {}
              name: nic-1
        resources:
          requests:
            memory: ${var.memory}
      networks:
        - name: default
          pod: {}
        - multus:
            networkName: ${var.namespace}/${var.network_name}
          name: nic-1
      volumes:
        - name: disk-0
          containerDisk:
            image: ${var.namespace}/${var.image_name}
        - name: cloudinitdisk
          cloudInitNoCloud:
            networkData: |
              version: 2
              ethernets:
                eth0:
                  dhcp4: false
                  match:
                    name: en*
                  addresses: ["${local.dev_worker_ips[count.index]}/24"]
                  gateway4: "10.0.0.1"
                  nameservers:
                    addresses: ["8.8.8.8", "1.1.1.1"]
            userData: |
              #cloud-config
              package_update: true
              packages:
                - qemu-guest-agent
              write_files:
                - path: /etc/rancher/rke2/config.yaml
                  content: |
                    server: https://${local.dev_master_ip}:9345
                  permissions: '0644'
              runcmd:
                - systemctl enable --now qemu-guest-agent.service
                - hostnamectl set-hostname dev-worker-${count.index + 1}
                - curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -
                - systemctl enable rke2-agent.service
                - systemctl start rke2-agent.service
EOF
EOT
  }
}

resource "null_resource" "sandbox_master" {
  provisioner "local-exec" {
    command = <<EOT
cat <<EOF | kubectl --kubeconfig ${var.harvester_kubeconfig} apply -f -
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: sandbox-master
  namespace: ${var.namespace}
spec:
  running: true
  template:
    metadata:
      labels:
        harvesterhci.io/vmName: sandbox-master
    spec:
      domain:
        cpu:
          cores: ${var.cpu}
        devices:
          disks:
            - disk:
                bus: virtio
              name: disk-0
              bootOrder: 1
            - disk:
                bus: virtio
              name: cloudinitdisk
          interfaces:
            - masquerade: {}
              name: default
            - bridge: {}
              name: nic-1
        resources:
          requests:
            memory: ${var.memory}
      networks:
        - name: default
          pod: {}
        - multus:
            networkName: ${var.namespace}/${var.network_name}
          name: nic-1
      volumes:
        - name: disk-0
          containerDisk:
            image: ${var.namespace}/${var.image_name}
        - name: cloudinitdisk
          cloudInitNoCloud:
            networkData: |
              version: 2
              ethernets:
                eth0:
                  dhcp4: false
                  match:
                    name: en*
                  addresses: ["${local.sandbox_master_ip}/24"]
                  gateway4: "10.0.0.1"
                  nameservers:
                    addresses: ["8.8.8.8", "1.1.1.1"]
            userData: |
              #cloud-config
              package_update: true
              packages:
                - qemu-guest-agent
              write_files:
                - path: /etc/rancher/rke2/config.yaml
                  content: |
                    bind-address: ${local.sandbox_master_ip}
                    advertise-address: ${local.sandbox_master_ip}
                    tls-san:
                      - ${local.sandbox_master_ip}
                  permissions: '0644'
              runcmd:
                - systemctl enable --now qemu-guest-agent.service
                - hostnamectl set-hostname sandbox-master
                - curl -sfL https://get.rke2.io | sh -
                - systemctl enable rke2-server.service
                - systemctl start rke2-server.service
EOF
EOT
  }
}

resource "null_resource" "sandbox_workers" {
  count = var.worker_count

  provisioner "local-exec" {
    command = <<EOT
cat <<EOF | kubectl --kubeconfig ${var.harvester_kubeconfig} apply -f -
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: sandbox-worker-${count.index + 1}
  namespace: ${var.namespace}
spec:
  running: true
  template:
    metadata:
      labels:
        harvesterhci.io/vmName: sandbox-worker-${count.index + 1}
    spec:
      domain:
        cpu:
          cores: ${var.cpu}
        devices:
          disks:
            - disk:
                bus: virtio
              name: disk-0
              bootOrder: 1
            - disk:
                bus: virtio
              name: cloudinitdisk
          interfaces:
            - masquerade: {}
              name: default
            - bridge: {}
              name: nic-1
        resources:
          requests:
            memory: ${var.memory}
      networks:
        - name: default
          pod: {}
        - multus:
            networkName: ${var.namespace}/${var.network_name}
          name: nic-1
      volumes:
        - name: disk-0
          containerDisk:
            image: ${var.namespace}/${var.image_name}
        - name: cloudinitdisk
          cloudInitNoCloud:
            networkData: |
              version: 2
              ethernets:
                eth0:
                  dhcp4: false
                  match:
                    name: en*
                  addresses: ["${local.sandbox_worker_ips[count.index]}/24"]
                  gateway4: "10.0.0.1"
                  nameservers:
                    addresses: ["8.8.8.8", "1.1.1.1"]
            userData: |
              #cloud-config
              package_update: true
              packages:
                - qemu-guest-agent
              write_files:
                - path: /etc/rancher/rke2/config.yaml
                  content: |
                    server: https://${local.sandbox_master_ip}:9345
                  permissions: '0644'
              runcmd:
                - systemctl enable --now qemu-guest-agent.service
                - hostnamectl set-hostname sandbox-worker-${count.index + 1}
                - curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -
                - systemctl enable rke2-agent.service
                - systemctl start rke2-agent.service
EOF
EOT
  }
}

