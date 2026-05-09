# Q8 — CiliumNetworkPolicy

Create 3 Cilium policies in `team-iris`. Do not modify existing `default-allow` policy.

## Existing policy

```bash
kubectl -n team-iris get ciliumnetworkpolicy
kubectl -n team-iris describe ciliumnetworkpolicy default-allow
```

The `default-allow` policy allows all intra-namespace traffic + DNS. Your new policies add restrictions on top.

## Find pod labels

```bash
kubectl -n team-iris get pods --show-labels
kubectl -n team-iris get svc database -o yaml  # check what labels it selects
```

## Policy p1 — L3 deny: messenger → database

```bash
kubectl apply -f p1.yaml
```

Denies all traffic from Pods with `type=messenger` to Pods behind Service `database`.

## Policy p2 — L4 deny: transmitter → database (ICMP only)

```bash
kubectl apply -f p2.yaml
```

Denies ICMP (ping) from Deployment `transmitter` to Pods behind Service `database`.
TCP/UDP traffic from transmitter to database is still allowed.

## Policy p3 — Mutual authentication: database → messenger

```bash
kubectl apply -f p3.yaml
```

Requires mutual TLS authentication for traffic from `type=database` Pods to `type=messenger` Pods.
Cilium uses its mTLS implementation — both sides must have valid Cilium-managed identities.

## Verification

```bash
# p1: messenger should NOT be able to reach database
kubectl -n team-iris exec deploy/messenger -- curl database -m 3  # should timeout/fail

# p2: transmitter ping to database should fail
kubectl -n team-iris exec deploy/transmitter -- ping -c2 <database-pod-ip>  # should fail
# But TCP should still work
kubectl -n team-iris exec deploy/transmitter -- curl database -m 3  # should succeed

# p3: verify policy exists (functional test requires Cilium mTLS setup)
kubectl -n team-iris get ciliumnetworkpolicy p3
```

## Notes on policy interactions

- `egressDeny` takes precedence over `egress` rules
- Multiple `egress`/`egressDeny` entries in the same policy are OR'd
- Cilium uses an identity model — `toEndpoints` matches by Pod labels, not IP
- `authentication.mode: required` needs Cilium with mutual auth feature enabled

## Getting the right label for "Pods behind Service database"

```bash
kubectl -n team-iris get svc database -o jsonpath='{.spec.selector}'
```

Use those labels in `toEndpoints.matchLabels` instead of `type: database` if they differ.
