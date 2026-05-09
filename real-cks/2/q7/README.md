# Q7 — KubeletConfiguration

Set `containerLogMaxSize: 5Mi` and `containerLogMaxFiles: 3` cluster-wide via kubeadm.

## Kubeadm way (ConfigMap first, then per-node)

The "kubeadm way" means:
1. Update the `kubelet-config` ConfigMap in `kube-system` (new nodes pick this up on join)
2. Download and apply it on each existing node
3. Restart kubelet on each node

## Step 1 — Edit the kubelet-config ConfigMap

```bash
kubectl -n kube-system edit configmap kubelet-config
```

Inside the `data.kubelet` YAML block, add or modify:
```yaml
containerLogMaxSize: "5Mi"
containerLogMaxFiles: 3
```

Full context of what you're looking for:
```yaml
apiVersion: v1
data:
  kubelet: |
    apiVersion: kubelet.config.k8s.io/v1beta1
    kind: KubeletConfiguration
    ...
    containerLogMaxSize: "5Mi"     # add this
    containerLogMaxFiles: 3        # add this
    ...
```

## Step 2 — Apply on control-plane (cks9640)

```bash
sudo kubeadm upgrade node phase kubelet-config
sudo systemctl restart kubelet
sudo systemctl status kubelet
```

## Step 3 — Apply on worker node (cks9640-node1)

```bash
ssh cks9640-node1
sudo kubeadm upgrade node phase kubelet-config
sudo systemctl restart kubelet
sudo systemctl status kubelet
exit
```

## Verification

```bash
# Check the applied config on each node
ssh cks9640-node1 "sudo cat /var/lib/kubelet/config.yaml | grep -E 'containerLog'"
sudo cat /var/lib/kubelet/config.yaml | grep -E 'containerLog'
```

Expected:
```
containerLogMaxFiles: 3
containerLogMaxSize: 5Mi
```

## Alternative: manual edit of /var/lib/kubelet/config.yaml

If `kubeadm upgrade node phase kubelet-config` isn't available, edit `/var/lib/kubelet/config.yaml` directly on each node and restart kubelet. But the ConfigMap must still be updated first for the "kubeadm way" requirement.
