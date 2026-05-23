variable "vm_count" {
  default = 5
}

variable "network_name" {
  default = "mgmt-br"
}

variable "ssh_key" {
  description = "SSH public key"
  type        = string
}

variable "image_name" {
  description = "Harvester image name"
  type        = string
}

variable "namespace" {
  default = "default"
}
