#!/bin/bash
# Q17 | Update Kubernetes: 1.33.4 → 1.34.1
# Node layout:
#   Controlplane: cks9640
#   Worker:       cks9640-node1

set -euo pipefail

TARGET_VERSION="1.34.1"
PACKAGE_VERSION="1.34.1-1.1"

### ─── CONTROLPLANE (cks9640) ───────────────────────────────────────────────

echo "=== CONTROLPLANE: draining cks9640 ==="
kubectl drain cks9640 --ignore-daemonsets

# If kubeadm is not yet at 1.34.1, upgrade it first:
# apt-mark unhold kubeadm
# apt-get install -y kubeadm=${PACKAGE_VERSION}
# apt-mark hold kubeadm

echo "=== CONTROLPLANE: running kubeadm upgrade apply ==="
sudo kubeadm upgrade apply v${TARGET_VERSION}

echo "=== CONTROLPLANE: upgrading kubelet and kubectl ==="
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=${PACKAGE_VERSION} kubectl=${PACKAGE_VERSION}
sudo apt-mark hold kubelet kubectl

echo "=== CONTROLPLANE: restarting kubelet ==="
sudo service kubelet restart

echo "=== CONTROLPLANE: uncordoning cks9640 ==="
kubectl uncordon cks9640

echo "=== CONTROLPLANE: verifying ==="
kubectl get nodes

### ─── WORKER (cks9640-node1) ───────────────────────────────────────────────

echo ""
echo "=== WORKER: draining cks9640-node1 ==="
kubectl drain cks9640-node1 --ignore-daemonsets

echo "=== WORKER: SSH and upgrade ==="
# Run the following on cks9640-node1 (via ssh):
cat << 'WORKER_SCRIPT'
sudo -i

# Upgrade kubeadm on the worker
apt-mark unhold kubeadm
apt-get install -y kubeadm=1.34.1-1.1
apt-mark hold kubeadm

# Pull new kubelet config from the already-upgraded controlplane
kubeadm upgrade node

# Upgrade kubelet and kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.34.1-1.1 kubectl=1.34.1-1.1
apt-mark hold kubelet kubectl

# Restart kubelet
service kubelet restart

exit
WORKER_SCRIPT

echo "=== WORKER: uncordoning cks9640-node1 ==="
kubectl uncordon cks9640-node1

echo "=== FINAL: verify cluster version ==="
kubectl get nodes
# Expected output:
# NAME              STATUS   ROLES           AGE   VERSION
# cks9640           Ready    control-plane   ...   v1.34.1
# cks9640-node1     Ready    <none>          ...   v1.34.1
