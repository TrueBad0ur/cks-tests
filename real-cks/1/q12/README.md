# Q12 — ImagePolicyWebhook

Block images matching patterns (e.g. `danger`, `malware`) via an admission webhook.

## Files

| File | Purpose |
|---|---|
| `admission-config.yaml` | AdmissionConfiguration for the ImagePolicyWebhook plugin |
| `webhook-kubeconfig.yaml` | Kubeconfig pointing apiserver to the webhook server |
| `apiserver-patch.yaml` | Snippets to add to `/etc/kubernetes/manifests/kube-apiserver.yaml` |
| `webhook-deploy.yaml` | Namespace + Deployment + Service for the webhook server |
| `webhook-server/server.py` | Python webhook server |
| `webhook-server/Dockerfile` | Image build |
| `webhook-server/Makefile` | Multi-arch build via buildx |

## Setup order

### 1. Build and push the webhook image

```bash
cd webhook-server
make build   # pushes to docker.io/truebad0ur/image-policy-webhook:latest
```

### 2. Deploy the webhook server

```bash
kubectl apply -f webhook-deploy.yaml
kubectl -n team-white get pods   # wait until Running
```

### 3. Get the ClusterIP

```bash
kubectl -n team-white get svc image-policy-webhook -ojsonpath='{.spec.clusterIP}'
```

**Important:** the apiserver runs on host network and cannot resolve `*.svc` cluster DNS names.
Always use the ClusterIP directly in `webhook-kubeconfig.yaml`.

### 4. Copy configs to the master node

```bash
ssh user@<master-ip>
sudo mkdir -p /etc/kubernetes/webhook
sudo cp admission-config.yaml /etc/kubernetes/webhook/
sudo cp webhook-kubeconfig.yaml /etc/kubernetes/webhook/webhook.yaml
```

### 5. Edit kube-apiserver.yaml

```bash
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

Add to `command`:
```yaml
- --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
- --admission-control-config-file=/etc/kubernetes/webhook/admission-config.yaml
```

Add to `volumeMounts`:
```yaml
- mountPath: /etc/kubernetes/webhook
  name: webhook-config
  readOnly: true
```

Add to `volumes`:
```yaml
- name: webhook-config
  hostPath:
    path: /etc/kubernetes/webhook
    type: DirectoryOrCreate
```

### 6. Wait for apiserver to restart

```bash
watch crictl ps   # wait until kube-apiserver is Running again
```

### 7. Verify

```bash
kubectl run test-bad --image=danger/evil:latest   # Forbidden
kubectl run test-ok  --image=nginx:alpine          # created
```

## How it works

```
kubectl create pod
      ↓
kube-apiserver
      ↓
ImagePolicyWebhook plugin
      ↓  POST /validate  (ImageReview object)
webhook server
      ↓  {allowed: true/false}
kube-apiserver allows or rejects
```

## defaultAllow behavior

| Value | Webhook unreachable |
|---|---|
| `true` | all images allowed (safe for cluster, insecure) |
| `false` | all images blocked (secure, but breaks cluster if webhook is down) |

## Pitfalls

- **DNS**: apiserver cannot resolve `*.svc` names — use ClusterIP in `webhook-kubeconfig.yaml`
- **Cache**: if apiserver started with a broken kubeconfig (DNS name that failed), it caches `defaultAllow` and stops calling the webhook — restart required after fixing the kubeconfig
- **Restart**: after changing `webhook-kubeconfig.yaml` on disk, the apiserver must be restarted to pick up the new kubeconfig
