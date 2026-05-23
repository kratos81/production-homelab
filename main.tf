# -------------------------------------------------------------------
# Cloud Image — Ubuntu 22.04 (downloaded to Proxmox storage)
# -------------------------------------------------------------------
resource "proxmox_virtual_environment_download_file" "ubuntu2204" {
  content_type = "iso"
  datastore_id = var.proxmox_iso_datastore
  node_name    = var.proxmox_node
  url          = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
  file_name    = "ubuntu-22.04-server-cloudimg-amd64.img"
}
