# Q14 — ETCD Secret Encryption

Encrypt Secrets at rest in etcd using `aesgcm`.

## Files

| File | Purpose |
|---|---|
| `encryption-config.yaml` | EncryptionConfiguration (aesgcm + identity fallback) |
| `apiserver-patch.yaml` | Snippets to add to `kube-apiserver.yaml` |
| `test-secret.yaml` | Secret to create and verify encryption |

## Setup

### 1. Copy EncryptionConfiguration to master

```bash
ssh user@<master-ip>
sudo mkdir -p /etc/kubernetes/etcd
sudo cp encryption-config.yaml /etc/kubernetes/etcd/ec.yaml
```

### 2. Edit kube-apiserver.yaml

```bash
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

Add to `command`:
```yaml
- --encryption-provider-config=/etc/kubernetes/etcd/ec.yaml
```

Add to `volumeMounts`:
```yaml
- mountPath: /etc/kubernetes/etcd
  name: etcd-enc
  readOnly: true
```

Add to `volumes`:
```yaml
- name: etcd-enc
  hostPath:
    path: /etc/kubernetes/etcd
    type: DirectoryOrCreate
```

### 3. Wait for apiserver restart

```bash
watch crictl ps   # wait until kube-apiserver is Running
```

### 4. Re-encrypt existing Secrets

New Secrets will be encrypted automatically. Existing ones must be rewritten:

```bash
kubectl get secrets -A -o json | kubectl replace -f -
```

Or for a specific namespace (as in the exam):

```bash
kubectl -n team-magenta get secrets -o json | kubectl replace -f -
```

## Verification

```bash
# Create a test secret
kubectl apply -f test-secret.yaml

# Read it directly from etcd — should start with k8s:enc:aesgcm:
kubectl -n kube-system exec etcd-master -- etcdctl \
  --cert /etc/kubernetes/pki/etcd/server.crt \
  --key /etc/kubernetes/pki/etcd/server.key \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  get /registry/secrets/default/test-enc | cat

# Encrypted output starts with:
# k8s:enc:aesgcm:v1:key1:...
# (binary garbage after — that's the ciphertext)

# Plaintext (not encrypted) would start with:
# k8s:...{"kind":"Secret"...
```

## How it works

```
kubectl create secret
        ↓
kube-apiserver
        ↓  encrypts with aesgcm key1
etcd stores: k8s:enc:aesgcm:v1:key1:<ciphertext>

kubectl get secret
        ↓
kube-apiserver reads from etcd
        ↓  decrypts with aesgcm key1
returns plaintext to client
```

## Provider order matters

```yaml
providers:
  - aesgcm:      # first = used for writing (encryption)
      keys:
        - name: key1
          secret: d0hhVGFTZUN1UmVQYVNzIQ==
  - identity: {} # fallback = allows reading unencrypted secrets
```

- First provider is used for all new writes.
- `identity: {}` as fallback lets apiserver read old unencrypted secrets during migration.
- Once all secrets are re-encrypted, `identity` can be removed.
- Removing `identity` before re-encrypting = apiserver cannot read old secrets → cluster breaks.

## Key rotation

To rotate the key: add the new key first, keep the old one second, restart apiserver, re-encrypt all secrets, then remove the old key.

```yaml
providers:
  - aesgcm:
      keys:
        - name: key2   # new key — used for writing
          secret: <new-base64>
        - name: key1   # old key — still used for reading
          secret: d0hhVGFTZUN1UmVQYVNzIQ==
  - identity: {}
```
