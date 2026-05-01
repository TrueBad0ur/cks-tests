# Q13 — CiliumNetworkPolicy: Block Metadata Server

Block egress to the metadata server on port 9055 from namespace `metadata-access`.
Allow all other egress: internet, same namespace, kube-system (DNS).

## Files

| File | Purpose |
|---|---|
| `cilium-network-policy.yaml` | CiliumNetworkPolicy with egress allow + egressDeny |
| `namespace.yaml` | Namespace `metadata-access` |
| `test-pods.yaml` | pod1 (curl loop), pod2 (nginx), metadata-server (mock on port 9055) |

## Setup

```bash
kubectl apply -f namespace.yaml
kubectl apply -f test-pods.yaml

# Watch pod1 logs — before policy, both targets return OK
kubectl -n metadata-access logs -f pod1

# Apply policy
kubectl apply -f cilium-network-policy.yaml

# After ~5s: metadata-server shows FAILED/TIMEOUT, pod2 still OK
```

## Verification (manual)

```bash
# Should be BLOCKED
kubectl exec -it -n metadata-access pod1 -- curl --max-time 3 http://metadata-server.metadata-access.svc.cluster.local:9055

# Should be ALLOWED — same namespace
kubectl exec -it -n metadata-access pod1 -- curl --max-time 3 http://pod2.metadata-access.svc.cluster.local

# Should be ALLOWED — DNS
kubectl exec -it -n metadata-access pod1 -- nslookup kubernetes.default.svc.cluster.local

# Should be ALLOWED — internet
kubectl exec -it -n metadata-access pod1 -- curl --max-time 5 http://example.com
```

## How the policy works

```
egressDeny takes precedence over egress allow rules.

egress (OR between entries):
  1. toCIDR 0.0.0.0/0          → external internet IPs
  2. toEndpoints {}             → all pods in same namespace
  3. toEndpoints kube-system    → DNS, CoreDNS

egressDeny:
  toEndpoints app=metadata-server
  AND toPorts 9055/TCP          → blocked
```

## toCIDR vs toEndpoints for egressDeny

On **orifinal server** the metadata server is an external host at `192.168.100.21` — `toCIDR` works there.

In a **local cluster** the metadata server is a pod. `toCIDR` does not match ClusterIPs or pod IPs
for cluster-internal traffic — Cilium intercepts at the pod identity level, not the IP level.
Use `toEndpoints` with a label selector instead.

| Target | Correct rule |
|---|---|
| External host / VM | `toCIDR` |
| Pod / Service in cluster | `toEndpoints` |

## Why 0.0.0.0/0 does not cover pod-to-pod traffic

Cilium uses an identity-based model for cluster-internal traffic.
`0.0.0.0/0` only applies to external (non-cluster) IP addresses.
Same-namespace and kube-system traffic must be explicitly allowed via `toEndpoints`.
