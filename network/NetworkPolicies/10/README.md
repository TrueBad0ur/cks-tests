# Task 10 — Label-based access control across namespaces

## Task

Namespace `np-10-app` has pod `app` (serves on port 8080).  
Namespace `np-10-internal` has pods `trusted` (role=trusted) and `blocked-internal` (role=blocked), both serve on port 9090.

**Create NetworkPolicies to enforce:**
1. `trusted` (role=trusted) → `app:8080`: **allowed**
2. `blocked-internal` (role=blocked) → `app:8080`: **blocked**
3. `app` → `trusted:9090`: **allowed**

## Apply environment

```bash
kubectl apply -f configs/
```

## Check

```bash
kubectl -n np-10-internal logs -f deploy/trusted          # [->app:8080] OK
kubectl -n np-10-internal logs -f deploy/blocked-internal # [->app:8080] FAIL
kubectl -n np-10-app      logs -f deploy/app              # [->trusted:9090] OK
```

## Automated check

```bash
bash configs/verify.sh
```

## Key concept: AND condition across namespaces

To allow only pods with a specific label FROM a specific namespace, combine `namespaceSelector` and `podSelector` under the same `-`:

```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: np-10-internal
    podSelector:
      matchLabels:
        role: trusted
  ports:
  - protocol: TCP
    port: 8080
```

Two separate `-` items would be OR (any pod in namespace OR any pod with label anywhere).  
One `-` item with both selectors is AND (pod with label IN that namespace).
