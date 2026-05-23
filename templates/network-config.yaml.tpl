version: 2
ethernets:
  enp1s0:
    dhcp4: false
    dhcp6: false
    addresses:
      - ${static_ip}/24
    routes:
      - to: default
        via: 10.0.0.1
    nameservers:
      addresses:
        - 10.0.0.1
        - 8.8.8.8
