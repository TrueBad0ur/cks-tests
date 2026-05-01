# Q17 — Audit Log Policy

Configure apiserver audit logging with a policy that logs:
- Secrets at `Metadata` level
- `system:nodes` group at `RequestResponse` level
- Everything else: `None`

## Files

| File | Purpose |
|---|---|
| `audit-policy.yaml` | Audit Policy manifest |
| `apiserver-patch.yaml` | Snippets to add to `kube-apiserver.yaml` |

## Setup

### 1. Create directories and copy policy on master

```bash
ssh user@<master-ip>
sudo mkdir -p /etc/kubernetes/audit/logs
sudo cp audit-policy.yaml /etc/kubernetes/audit/policy.yaml
```

### 2. Edit kube-apiserver.yaml

```bash
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

Add to `command`:
```yaml
- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/etc/kubernetes/audit/logs/audit.log
- --audit-log-maxbackup=1
- --audit-log-maxsize=100
- --audit-log-maxage=7
```

Add to `volumeMounts`:
```yaml
- mountPath: /etc/kubernetes/audit
  name: audit
```

Add to `volumes`:
```yaml
- name: audit
  hostPath:
    path: /etc/kubernetes/audit
    type: DirectoryOrCreate
```

### 3. Restart apiserver cleanly (to get a fresh log)

```bash
cd /etc/kubernetes/manifests
sudo mv kube-apiserver.yaml ..
# wait until apiserver stops
sudo crictl ps | grep apiserver   # should be empty

sudo truncate -s 0 /etc/kubernetes/audit/logs/audit.log

sudo mv ../kube-apiserver.yaml .
# wait until apiserver is back
sudo crictl ps | grep apiserver
```

## Verification

```bash
# Read a Secret — should produce Metadata-level entry
kubectl get secret -n kube-system bootstrap-token-* -ojson 2>/dev/null || true
```

Audit log is NDJSON (one JSON object per line). Use line-by-line parsing:

```bash
# Pretty-print last N entries
sudo tail -20 /etc/kubernetes/audit/logs/audit.log \
  | python3 -c 'import sys,json; [print(json.dumps(json.loads(l),indent=2)) for l in sys.stdin if l.strip()]'

# Filter Secret entries — show level, verb, resource, user
sudo grep '"resource":"secrets"' /etc/kubernetes/audit/logs/audit.log \
  | python3 -c '
import sys, json
for line in sys.stdin:
    e = json.loads(line)
    print(json.dumps({
        "level": e.get("level"),
        "verb": e.get("verb"),
        "resource": e.get("objectRef", {}).get("resource"),
        "user": e.get("user", {}).get("username"),
    }))
'

# Follow live (one line at a time, no json.tool)
sudo tail -f /etc/kubernetes/audit/logs/audit.log
```

Expected for Secret access:
```json
"level": "Metadata",
"verb": "get",
"resource": "secrets",
"requestObject": null,    ← body not logged at Metadata level
"responseObject": null
```

Expected for node actions:
```json
"level": "RequestResponse",
"user": {"groups": ["system:nodes", ...]},
"requestObject": {...},   ← full body logged
"responseObject": {...}
```

## Audit levels

| Level | What is logged |
|---|---|
| `None` | nothing |
| `Metadata` | method, URL, user, source IP, timestamp — no body |
| `Request` | + request body |
| `RequestResponse` | + response body |

## Why rule order matters

First matching rule wins. If `None` were first, nothing would be logged.
Always put specific rules before the catch-all `None`.
