# Q2 — Runtime Security with Falco

Find misbehaving Pods using Falco rules, fix rule output format, collect logs.

## Setup

Connect to the worker node from the control plane:
```bash
ssh cks5632-node1
sudo -i
```

Custom rules file is at `/etc/falco/rules.d/falco_custom.yaml`.

## Task 1 — Find Pod modifying /etc/passwd (httpd image)

```bash
# Tail Falco log for passwd modification events
journalctl -u falco -f | grep "passwd modified"
# or
tail -f /var/log/falco/falco.log | grep "passwd"
```

Find the Pod name from the event (`container_name` field), then on the control plane:

```bash
# Find the Deployment
kubectl get pods --all-namespaces -o wide | grep <container_name>
kubectl -n <namespace> get pod <pod> -o jsonpath='{.metadata.ownerReferences[0].name}'
# Scale down
kubectl -n <namespace> scale rs/<replicaset-name> --replicas=0
# Or get deployment directly
kubectl -n <namespace> get deploy | grep httpd
kubectl -n <namespace> scale deploy/<name> --replicas=0
```

## Task 2 — Find Pod running package manager (nginx image), fix log format, collect logs

### Identify the Pod

```bash
# On worker node
journalctl -u falco -f | grep "Package management"
```

The rule output line to modify is:
```
Package management process launched %evt.time.s %container.id %container.name %user.name
```

Required fields in order: `time-with-nanoseconds`, `container-id`, `container-name`, `user-name`

Falco field mappings:
| Required | Falco field |
|----------|------------|
| time-with-nanoseconds | `%evt.time` |
| container-id | `%container.id` |
| container-name | `%container.name` |
| user-name | `%user.name` |

### Edit the rule on the worker node

```bash
vim /etc/falco/rules.d/falco_custom.yaml
```

Change the output line to:
```yaml
  output: >
    Package management process launched
    %evt.time %container.id %container.name %user.name
```

### Restart Falco and collect logs

```bash
systemctl restart falco

# Collect for at least 20 seconds
timeout 30 journalctl -u falco -f | grep "Package management" >> /opt/course/2/falco.log
# or
tail -f /var/log/falco/falco.log | grep "Package management" | head -20 > /opt/course/2/falco.log
```

### Scale down the nginx Deployment

```bash
# Back on control plane
kubectl get pods --all-namespaces | grep nginx
kubectl -n <namespace> scale deploy/<name> --replicas=0
```

## Verification

```bash
cat /opt/course/2/falco.log
# Each line should look like:
# Package management process launched 12:34:56.123456789 abc123def456 my-container root
```

## Falco Time Fields

| Field | Format |
|-------|--------|
| `%evt.time` | time with nanoseconds — `HH:MM:SS.NNNNNNNNN` |
| `%evt.time.s` | seconds only — `HH:MM:SS` |
| `%evt.datetime` | ISO-8601 datetime |
