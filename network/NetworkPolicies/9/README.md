# Task 9 — Default deny + multiple additive policies

## Task

Namespace `np-9` has three pods: `web`, `api`, `db`.  
All three continuously curl each other.

**Step 1:** Create a policy that denies ALL ingress AND egress for ALL pods in `np-9`.

**Step 2:** Create a second policy that allows `web` → `api` on port 80 (ingress on api + egress from web).

**Step 3:** Create a third policy that allows `api` → `db` on port 5432 (ingress on db + egress from api).

After all three policies:
- `web` → `api:80`: allowed
- `api` → `db:5432`: allowed
- `web` → `db:5432`: blocked
- `db` → anything: blocked

## Apply environment

```bash
kubectl apply -f configs/
```

## Check

```bash
kubectl -n np-9 logs -f deploy/web  # api OK, db FAIL
kubectl -n np-9 logs -f deploy/api  # db OK
kubectl -n np-9 logs -f deploy/db   # web FAIL, api FAIL
```

## Automated check

```bash
bash configs/verify.sh
```

## Key concept: multiple policies are OR'd

When multiple NetworkPolicies select the same pod, their rules are **unioned (OR'd)**:
- Policy A allows web → api
- Policy B allows api → db
- Result: web can reach api, api can reach db, but web still cannot reach db

A "default deny all" policy (`podSelector: {}` with empty ingress/egress) establishes the baseline.  
Each additional policy adds exceptions on top of it.

## Structure hint

You need 3 separate NetworkPolicy objects.  
Policy 1 (default-deny): `podSelector: {}`, `policyTypes: [Ingress, Egress]`, no rules.  
Policy 2 (web→api): controls both web's egress AND api's ingress.  
Policy 3 (api→db): controls both api's egress AND db's ingress.

Or: combine ingress+egress per pod into one policy each. Your choice.
