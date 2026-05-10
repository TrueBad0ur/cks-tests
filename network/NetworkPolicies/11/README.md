# Task 11 — Bidirectional access between two namespaces

## Task

Two namespaces: `np-11-a` and `np-11-b`.  
A third namespace `np-11-outside` represents everyone else.

- `service-a` in `np-11-a` and `service-b` in `np-11-b` must be able to reach each other
- `outsider` in `np-11-outside` must NOT reach either `service-a` or `service-b`
- `service-a` and `service-b` must NOT reach `outsider`

**Create NetworkPolicies to enforce this. No existing policies in any namespace.**

## Apply environment

```bash
kubectl apply -f configs/
```

## Check

```bash
kubectl -n np-11-a logs -f deploy/service-a        # [->b] OK, [->outsider] FAIL
kubectl -n np-11-b logs -f deploy/service-b        # [->a] OK, [->outsider] FAIL
kubectl -n np-11-outside logs -f deploy/outsider   # [->a] FAIL, [->b] FAIL
```

## Automated check

```bash
bash configs/verify.sh
```

## Key concept: bidirectional requires both ingress and egress

To allow A↔B you need 4 things:
1. Egress from A to B (policy in np-11-a)
2. Ingress on B from A (policy in np-11-b)
3. Egress from B to A (policy in np-11-b)
4. Ingress on A from B (policy in np-11-a)

Forgetting any one of these breaks the connection in one direction.  
You can combine 1+4 into one policy for np-11-a, and 2+3 into one policy for np-11-b.  
Don't forget DNS in egress policies.
