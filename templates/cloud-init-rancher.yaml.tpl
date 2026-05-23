#cloud-config
package_update: true
packages: [curl, open-iscsi, nfs-common]
%{ if ssh_key != "" }
ssh_authorized_keys: [${ssh_key}]
%{ endif }
ssh_pwauth: true
disable_root: false
write_files:
- path: /etc/rancher/rke2/config.yaml
  content: |
    token: ${rke2_token}
    tls-san: [$(hostname), 10.0.0.50, rancher.homelab.local]
- path: /etc/ssh/sshd_config.d/99-root.conf
  content: "PermitRootLogin yes\n"
runcmd:
- systemctl restart sshd
- systemctl enable --now iscsid
- curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=${rke2_version} sh -
- systemctl enable --now rke2-server
- mkdir -p /root/.kube && ln -sf /etc/rancher/rke2/rke2.yaml /root/.kube/config
