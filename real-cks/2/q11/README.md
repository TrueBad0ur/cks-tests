# Q11 — Secrets in ETCD

Read the Secret `database-access` directly from ETCD and extract the password value.

## Setup

Must run as root on the control-plane node:
```bash
sudo -i
```

## Task 1 — Read Secret from ETCD directly

ETCD path for the secret: `/registry/secrets/team-daisy/database-access`

```bash
ETCDCTL_API=3 etcdctl \
  --cert /etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key /etc/kubernetes/pki/apiserver-etcd-client.key \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  --endpoints https://127.0.0.1:2379 \
  get /registry/secrets/team-daisy/database-access \
  > /opt/course/11/etcd-secret-content
```

Verify:
```bash
cat /opt/course/11/etcd-secret-content
# Should contain raw protobuf/JSON data with the secret values
```

## Task 2 — Extract and decode the "pass" key

If encryption at rest is NOT enabled (default):

```bash
# The value appears in the etcd output as base64-encoded
# Extract via kubectl (easier)
kubectl -n team-daisy get secret database-access \
  -o jsonpath='{.data.pass}' | base64 -d > /opt/course/11/database-password

cat /opt/course/11/database-password
```

If you must use only the etcd output:
```bash
# The etcd output contains base64 values, find the "pass" key
# Use strings to find readable content
strings /opt/course/11/etcd-secret-content | grep -A1 "pass"

# Decode whatever base64 value follows
echo "<base64-value>" | base64 -d > /opt/course/11/database-password
```

## Verification

```bash
# etcd raw content should have binary data
wc -c /opt/course/11/etcd-secret-content

# password file should have plain text
cat /opt/course/11/database-password
```

## Notes

- `ETCDCTL_API=3` must be set — etcdctl v3 API
- The cert paths use `apiserver-etcd-client` (not `server` or `peer`) credentials
- If encryption at rest is enabled, the etcd content will show `k8s:enc:aesgcm:v1:...` prefix and be unreadable — use kubectl to get the decoded value
- Do NOT add a trailing newline to the password file: `printf '%s' "$password" > /opt/course/11/database-password`
