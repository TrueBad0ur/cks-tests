# Q14 — Syscall Activity (kill syscall)

Find Pods in `team-tulip` using the `kill` syscall and scale them down.

## Find Pods and their nodes

```bash
kubectl -n team-tulip get pods -owide
# Note the NODE column
```

## Connect to the worker node

```bash
ssh cks5632-node1
sudo -i
```

## Find container processes

```bash
# List running containers
crictl ps

# For each container in team-tulip, get the PID
crictl inspect <container-id> | grep -i pid
# or
crictl inspect <container-id> | python3 -m json.tool | grep '"pid"'
```

## Trace syscalls with strace

```bash
# Attach strace to the container's main process
strace -p <pid> -e trace=kill -f 2>&1 | head -20
```

If `strace` is not available:
```bash
apt-get install -y strace
```

A process using `kill` syscall will show lines like:
```
kill(1, SIG_0) = 0
```

## Identify which Pod the offending container belongs to

```bash
crictl ps -o json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for c in data['containers']:
    print(c['id'], c['labels'].get('io.kubernetes.pod.name', ''), c['labels'].get('io.kubernetes.pod.namespace', ''))
"
```

Or simpler:
```bash
crictl ps | grep <container-id>
# Container name maps to pod via: crictl inspect <id> | grep -i 'pod.name'
```

## Scale down from control plane

```bash
# Exit worker node
exit

# Find the Deployment
kubectl -n team-tulip get pods <pod-name> -o jsonpath='{.metadata.ownerReferences[0].name}'
kubectl -n team-tulip get replicaset <rs-name> -o jsonpath='{.metadata.ownerReferences[0].name}'

# Scale to 0
kubectl -n team-tulip scale deployment/<deploy-name> --replicas=0
```

## Verification

```bash
kubectl -n team-tulip get pods   # offending pod should be gone
kubectl -n team-tulip get deployments   # replicas=0 for offending one
```

## Alternative: use /proc

If strace isn't available, inspect `/proc/<pid>/syscall` or use `perf`:
```bash
# Check what syscalls a process is making
cat /proc/<pid>/syscall

# Use perf if available
perf trace -p <pid> 2>&1 | grep kill
```
