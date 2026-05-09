# Q17 — Update Kubernetes

Upgrade cluster from 1.33.4 to 1.34.1 using apt and kubeadm.

## Overview

1. Upgrade control-plane (cks9640): drain → kubeadm upgrade → kubelet/kubectl → uncordon
2. Upgrade worker (cks9640-node1): drain → kubeadm upgrade node → kubelet/kubectl → uncordon

## Step 1 — Drain control-plane

```bash
kubectl drain cks9640 --ignore-daemonsets --delete-emptydir-data
```

## Step 2 — Upgrade kubeadm on control-plane

```bash
sudo -i

apt-get update
apt-cache madison kubeadm | grep 1.34.1   # verify availability

apt-get install -y kubeadm=1.34.1-1.1
kubeadm version   # verify
```

## Step 3 — Kubeadm upgrade plan and apply

```bash
kubeadm upgrade plan v1.34.1
kubeadm upgrade apply v1.34.1
# Confirm with 'y' when prompted
```

## Step 4 — Upgrade kubelet and kubectl on control-plane

```bash
apt-get install -y kubelet=1.34.1-1.1 kubectl=1.34.1-1.1
systemctl daemon-reload
systemctl restart kubelet
```

## Step 5 — Uncordon control-plane

```bash
exit   # back to normal user
kubectl uncordon cks9640
kubectl get nodes   # control-plane should show v1.34.1
```

## Step 6 — Drain worker node

```bash
kubectl drain cks9640-node1 --ignore-daemonsets --delete-emptydir-data
```

## Step 7 — Upgrade worker node

```bash
ssh cks9640-node1
sudo -i

apt-get update
apt-get install -y kubeadm=1.34.1-1.1
kubeadm upgrade node

apt-get install -y kubelet=1.34.1-1.1 kubectl=1.34.1-1.1
systemctl daemon-reload
systemctl restart kubelet

exit
exit
```

## Step 8 — Uncordon worker

```bash
kubectl uncordon cks9640-node1
```

## Verification

```bash
kubectl get nodes
# Both nodes should show VERSION 1.34.1

kubectl version
# Client and Server both 1.34.1
```

## Notes

- Package version suffix (`-1.1`) may vary — use `apt-cache madison kubeadm` to check exact version string
- `kubeadm upgrade apply` only runs on control-plane; workers use `kubeadm upgrade node`
- `--ignore-daemonsets` is required when draining — DaemonSet pods are managed separately
- Kubelet restart is required after upgrade: `systemctl restart kubelet`
- Hold packages to prevent accidental upgrades: `apt-mark hold kubelet kubeadm kubectl`
