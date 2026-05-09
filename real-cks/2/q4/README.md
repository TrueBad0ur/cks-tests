# Q4 — Pod Security Standard

Enforce `baseline` PSS on Namespace `team-rose` to block a hostPath-mounting Deployment.

## Context

Deployment `container-host-hacker` in `team-rose` mounts `/run/containerd` as a hostPath volume.
The `baseline` PSS forbids hostPath volumes → Pod will be rejected on recreation.

## Setup

### 1. Apply PSS label to the namespace

```bash
kubectl label namespace team-rose pod-security.kubernetes.io/enforce=baseline
# or apply namespace-patch.yaml:
kubectl apply -f namespace-patch.yaml
```

Verify:
```bash
kubectl get namespace team-rose -o jsonpath='{.metadata.labels}' | python3 -m json.tool
```

### 2. Delete the running Pod

```bash
kubectl -n team-rose get pods
kubectl -n team-rose delete pod <pod-name>
```

The ReplicaSet will try to recreate it → apiserver rejects it due to PSS.

### 3. Capture the rejection reason

```bash
kubectl -n team-rose get events --sort-by='.lastTimestamp' | grep -i "fail\|forbid\|violat\|error"
```

Write to the output file:
```bash
kubectl -n team-rose get events --sort-by='.lastTimestamp' \
  | grep -i "fail\|forbid\|violat\|error" \
  > /opt/course/4/logs
```

## Verification

```bash
# Pod should not exist or be in a failed state
kubectl -n team-rose get pods

# ReplicaSet events should show rejection
kubectl -n team-rose describe rs <replicaset-name> | grep -A5 "Events:"

# Log file should have rejection lines
cat /opt/course/4/logs
```

## Pod Security Standards — baseline restrictions

The `baseline` policy blocks (among others):
- `hostPath` volumes
- `hostPID`, `hostNetwork`, `hostIPC`
- Privileged containers
- Host port bindings

## Why this works

PSS is enforced via the `PodSecurity` admission controller (built-in since 1.25). The label on the Namespace is the only configuration needed. The controller rejects Pods at admission time — the ReplicaSet controller records the failure as an event.
