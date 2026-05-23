variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint URL"
  type        = string
  default     = "https://proxmox.homelab.local:8006"
}

variable "proxmox_username" {
  description = "Proxmox API username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name to deploy VMs on"
  type        = string
  default     = "pve"
}

variable "proxmox_datastore" {
  description = "Proxmox storage for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "proxmox_iso_datastore" {
  description = "Proxmox storage for ISO/cloud images and snippets"
  type        = string
  default     = "local"
}

variable "proxmox_bridge" {
  description = "Proxmox network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

variable "proxmox_vlan_tag" {
  description = "VLAN tag for VM network (0 = untagged)"
  type        = number
  default     = 0
}

variable "kubernetes_version" {
  description = "RKE2 Kubernetes version"
  type        = string
  default     = "v1.28.13+rke2r1"
}

variable "rke2_token" {
  description = "Shared secret for RKE2 node registration"
  type        = string
  sensitive   = true
}

variable "disk_size" {
  description = "Boot disk size (GB) for control plane VMs"
  type        = number
  default     = 100
}

variable "worker_disk_size" {
  description = "Boot disk size (GB) for worker VMs"
  type        = number
  default     = 100
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}
