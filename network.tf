# -------------------------------------------------------------------
# VM Network — uses existing Proxmox bridge
# -------------------------------------------------------------------
# Network is configured via var.proxmox_bridge (default: vmbr0)
# For VLAN-tagged networking, set var.proxmox_vlan_tag
#
# Proxmox network bridges are configured at the host level:
#   auto vmbr0
#   iface vmbr0 inet static
#       address 10.0.0.1/24
#       bridge-ports eno1
#       bridge-stp off
#       bridge-fd 0
