# -------------------------------------------------------------------
# VM Network — bridges VMs onto the 10.0.0.xx LAN (untagged/VLAN 1)
# -------------------------------------------------------------------
resource "harvester_network" "vm_lan" {
  name      = "vm-lan"
  namespace = var.vm_namespace

  vlan_id = 0

  cluster_network_name = "mgmt"

  route_mode = "auto"
}
