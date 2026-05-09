# Q13 — RBAC Operator

Fix permissions for `cert-signer` StatefulSet in `team-lilac` until it runs without RBAC errors.

## Diagnose

```bash
# Check current state
kubectl -n team-lilac get statefulset cert-signer
kubectl -n team-lilac get pods

# Read logs — if pod restarts too fast, use --previous
kubectl -n team-lilac logs cert-signer-0
kubectl -n team-lilac logs --previous cert-signer-0

# Repeat as you add permissions — new errors will surface
```

Typical error pattern:
```
Error from server (Forbidden): configmaps is forbidden: User "system:serviceaccount:team-lilac:cert-signer" ...
Error from server (Forbidden): certificatesigningrequests is forbidden: ...
```

## Apply RBAC

```bash
kubectl apply -f rbac.yaml
```

This creates:
- `Role` + `RoleBinding` in `team-lilac` for ConfigMap read access
- `ClusterRole` + `ClusterRoleBinding` for CSR list + approval

## Verify permissions

```bash
SA="system:serviceaccount:team-lilac:cert-signer"

kubectl auth can-i get configmaps -n team-lilac --as=$SA
kubectl auth can-i list configmaps -n team-lilac --as=$SA
kubectl auth can-i list certificatesigningrequests --as=$SA
kubectl auth can-i update certificatesigningrequests/approval --as=$SA
```

All should return `yes`.

## Watch for remaining errors

After applying RBAC, watch logs again:
```bash
kubectl -n team-lilac logs -f cert-signer-0
```

If new permission errors appear, add them to `rbac.yaml` and re-apply.
Apply minimal permissions — only what the logs actually ask for.

## Verification

```bash
# No restarts and no RBAC errors in logs
kubectl -n team-lilac get pods   # RESTARTS should stop increasing
kubectl -n team-lilac logs cert-signer-0 | grep -i "error\|forbidden"  # should be empty

# Operator running
kubectl -n team-lilac get statefulset cert-signer
```

## Notes on CSR approval RBAC

Approving CSRs requires two separate sub-resource permissions:
1. `certificatesigningrequests/approval` with verb `update` — controls ability to update approval conditions
2. `signers` with `resourceNames` specifying the signer — controls which signers can be approved

Without the `signers` permission, approval will be denied even if `approval` subresource is allowed.
