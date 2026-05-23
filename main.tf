# -------------------------------------------------------------------
# VM Image — Ubuntu 22.04 cloud image
# -------------------------------------------------------------------
resource "harvester_image" "ubuntu2204" {
  name         = "ubuntu-2204"
  namespace    = var.vm_namespace
  display_name = "Ubuntu 22.04 Server Cloud"
  source_type  = "download"
  url          = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"

  timeouts {
    create = "15m"
    delete = "5m"
  }
}

# -------------------------------------------------------------------
# SSH Key
# -------------------------------------------------------------------
resource "harvester_ssh_key" "rke2_key" {
  count      = var.ssh_public_key != "" ? 1 : 0
  name       = "${local.c2_name}-ssh-key"
  namespace  = var.vm_namespace
  public_key = var.ssh_public_key
}
