# -------------------------------------------------------------------
# VM Network — uses existing vSphere port group
# -------------------------------------------------------------------
# Network is referenced via data source in main.tf
# Configure the port group name in var.vsphere_network
# Default: "VM Network"
#
# For VLAN-backed networking, create a distributed port group in
# vCenter with the desired VLAN ID and reference it here.
