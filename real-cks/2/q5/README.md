# Q5 — NetworkPolicy

Restrict egress from `gateway-v1` and `gateway-v2` so they can only reach `team-ivy-private`.

## Context

- `team-ivy-private` has a NetworkPolicy protecting `api-private` — do not touch it
- `team-ivy-gateway` has `gateway-v1` and `gateway-v2` Deployments
- You need to add egress NetworkPolicies in `team-ivy-gateway`

## Policies

| Deployment | Destination Namespace | Allowed Ports |
|-----------|----------------------|---------------|
| gateway-v1 | team-ivy-private | 3000 |
| gateway-v2 | team-ivy-private | 4000, 5000 |

## Apply

```bash
kubectl apply -f networkpolicy-gateway-v1.yaml
kubectl apply -f networkpolicy-gateway-v2.yaml
```

## Check existing policy in team-ivy-private

```bash
kubectl -n team-ivy-private get networkpolicy
kubectl -n team-ivy-private describe networkpolicy
```

This tells you what labels the ingress policy uses to allow the gateway pods — make sure your pod labels match.

## Check gateway pod labels

```bash
kubectl -n team-ivy-gateway get pods --show-labels
```

If labels differ from `app: gateway-v1` / `app: gateway-v2`, update the `matchLabels` in the policies.

## Verification

```bash
# Get IP of api-private Pod
kubectl -n team-ivy-private get pods -owide

# Test from gateway-v1 pod — port 3000 should work
kubectl -n team-ivy-gateway exec deploy/gateway-v1 -- curl <api-private-ip>:3000 -m 3

# Port 4000 from gateway-v1 should fail (or time out)
kubectl -n team-ivy-gateway exec deploy/gateway-v1 -- curl <api-private-ip>:4000 -m 3

# Test from gateway-v2 pod — ports 4000 and 5000 should work
kubectl -n team-ivy-gateway exec deploy/gateway-v2 -- curl <api-private-ip>:4000 -m 3
kubectl -n team-ivy-gateway exec deploy/gateway-v2 -- curl <api-private-ip>:5000 -m 3
```

## Important: DNS egress

If the pods need DNS resolution, you may also need to allow UDP/TCP port 53 to kube-dns:

```yaml
  egress:
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: team-ivy-private
      ports:
        - port: 3000
          protocol: TCP
```

Add this only if the existing `default-allow` policy doesn't already cover DNS.
