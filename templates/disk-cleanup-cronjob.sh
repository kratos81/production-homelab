#!/bin/bash
# Disk cleanup script for RKE2 control plane nodes
# Runs weekly via cron to prevent disk from filling up

echo "=== Disk Cleanup Started: $(date) ==="
echo "Before: $(df -h / | tail -1)"

# 1. Clean journal logs (keep 200MB)
journalctl --vacuum-size=200M 2>/dev/null

# 2. Clean rotated logs
find /var/log -name "*.gz" -delete 2>/dev/null
find /var/log -name "*.old" -delete 2>/dev/null
find /var/log -name "*.[0-9]" -delete 2>/dev/null

# 3. Clean old pod logs (>50MB and older than 3 days)
find /var/log/pods -name "*.log.*" -mtime +3 -delete 2>/dev/null
find /var/log/pods -name "*.log" -size +50M -exec truncate -s 0 {} \; 2>/dev/null

# 4. Clean old etcd snapshots (keep latest 2)
SNAP_DIR="/var/lib/rancher/rke2/server/db/snapshots"
if [ -d "$SNAP_DIR" ]; then
  cd "$SNAP_DIR" && ls -t | tail -n +3 | xargs rm -f 2>/dev/null
fi

# 5. Clean containerd content blobs older than 5 days
CONTENT_DIR="/var/lib/rancher/rke2/agent/containerd/io.containerd.content.v1.content/blobs/sha256"
if [ -d "$CONTENT_DIR" ]; then
  find "$CONTENT_DIR" -atime +5 -type f -delete 2>/dev/null
fi

# 6. Clean apt cache
apt-get clean 2>/dev/null
rm -rf /var/cache/apt/archives/*.deb 2>/dev/null

# 7. Prune containerd images if crictl is available
CRICTL="/var/lib/rancher/rke2/bin/crictl"
if [ -x "$CRICTL" ]; then
  CRI_SOCK="unix:///run/k3s/containerd/containerd.sock"
  $CRICTL -r $CRI_SOCK rmi --prune 2>/dev/null
fi

echo "After: $(df -h / | tail -1)"
echo "=== Disk Cleanup Completed: $(date) ==="
