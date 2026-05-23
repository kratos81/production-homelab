variable "harvester_kubeconfig_path" {
  description = "Path to Harvester kubeconfig file"
  type        = string
  default     = "~/.kube/harvester.yaml"
}

variable "harvester_endpoint" {
  description = "Harvester API endpoint URL"
  type        = string
  default     = "https://10.0.0.1"
}

variable "cluster_name" {
  description = "Name of the RKE2 cluster"
  type        = string
  default     = "rke2-cluster-01"
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

variable "control_plane_count" {
  description = "Number of control plane nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "control_plane_cpu" {
  description = "CPUs for control plane VMs"
  type        = number
  default     = 4
}

variable "control_plane_memory" {
  description = "Memory (MiB) for control plane VMs"
  type        = number
  default     = 8192
}

variable "worker_cpu" {
  description = "CPUs for worker VMs"
  type        = number
  default     = 4
}

variable "worker_memory" {
  description = "Memory (MiB) for worker VMs"
  type        = number
  default     = 8192
}

variable "disk_size" {
  description = "Boot disk size (Gi) for control plane and management VMs"
  type        = string
  default     = "100Gi"
}

variable "worker_disk_size" {
  description = "Boot disk size (Gi) for worker VMs"
  type        = string
  default     = "100Gi"
}

variable "vm_namespace" {
  description = "Harvester namespace for VMs"
  type        = string
  default     = "default"
}

variable "cp_static_ip" {
  description = "Static IP for the first control plane node"
  type        = string
  default     = "10.0.0.100"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}
