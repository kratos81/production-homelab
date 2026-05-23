variable "vsphere_server" {
  description = "vCenter Server FQDN or IP"
  type        = string
}

variable "vsphere_user" {
  description = "vCenter username"
  type        = string
  default     = "administrator@vsphere.local"
}

variable "vsphere_password" {
  description = "vCenter password"
  type        = string
  sensitive   = true
}

variable "vsphere_datacenter" {
  description = "vSphere datacenter name"
  type        = string
  default     = "Datacenter"
}

variable "vsphere_cluster" {
  description = "vSphere cluster name"
  type        = string
  default     = "Cluster"
}

variable "vsphere_datastore" {
  description = "vSphere datastore for VM disks"
  type        = string
  default     = "datastore1"
}

variable "vsphere_network" {
  description = "vSphere network/port group for VMs"
  type        = string
  default     = "VM Network"
}

variable "vsphere_template" {
  description = "VM template name (Ubuntu 22.04 with cloud-init)"
  type        = string
  default     = "ubuntu-2204-template"
}

variable "vsphere_folder" {
  description = "vSphere folder for VMs"
  type        = string
  default     = "RKE2"
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
