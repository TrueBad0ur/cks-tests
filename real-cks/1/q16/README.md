# Q16 — Runtime Security with Falco

Add two custom Falco rules and verify they fire.

## Files

| File | Purpose |
|---|---|
| `falco-rules.yaml` | Raw rules (copy to `/etc/falco/falco_rules.local.yaml` on exam) |
| `falco-values.yaml` | Helm values to apply rules via `helm upgrade` |
| `test-pods.yaml` | Pods that trigger Rule 1 and Rule 2 |

## Setup

### Apply rules via Helm

```bash
helm upgrade falco falcosecurity/falco -n falco -f falco-values.yaml
```

The rules are added to the `falco-rules` ConfigMap. Falco pods reload automatically.

Verify the ConfigMap was updated:
```bash
kubectl -n falco get configmap falco-rules -ojsonpath='{.data}' | python3 -m json.tool
```

### Deploy trigger pods

```bash
kubectl apply -f test-pods.yaml
```

## Verification

Watch Falco logs from the node where the trigger pods run:

```bash
# Find which node the pods are on
kubectl get pod rule1-trigger rule2-trigger -owide

# Follow logs from the Falco pod on that node
FALCO_POD=$(kubectl -n falco get pod -owide | grep <node-name> | awk '{print $1}')
kubectl -n falco logs -f $FALCO_POD -c falco
```

Or watch all Falco pods at once:

```bash
kubectl -n falco --max-log-requests 7 logs -f -l app.kubernetes.io/name=falco -c falco | grep -E 'custom_rule_1|custom_rule_2'
```

Expected output:
```
custom_rule_1 file=/etc/kubernetes/ca.crt container=<id>
custom_rule_2 event_signal=0 event_pid=1 container=<id>
```

## On the exam (no Helm)

```bash
sudo vim /etc/falco/falco_rules.local.yaml
# paste contents of falco-rules.yaml

# Run Falco manually for 30+ seconds, save output
falco > /opt/course/16/logs
# Ctrl+C after 30s

grep custom_rule_1 /opt/course/16/logs | wc -l
grep custom_rule_2 /opt/course/16/logs | wc -l
```

## Rules explained

**Rule 1** — file access under `/etc/kubernetes` from containers:
- `container` — Falco macro: `container.id != host` (only containers, not host processes)
- `evt.type in (open, openat)` — file open syscalls
- `fd.name startswith /etc/kubernetes` — any path under that directory

**Rule 2** — kill syscall:
- `syscall.type = kill` — the `kill()` syscall (fired for any signal, not just SIGKILL)
- `evt.arg.sig` — signal number (0 = existence check, 9 = SIGKILL, 15 = SIGTERM)
- fires on every signal sent, including internal process management
