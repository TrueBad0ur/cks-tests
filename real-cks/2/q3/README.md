# Q3 — Manual Static Security Analysis

Review files under `/opt/course/3/files` for credential exposure issues.

## Files to Review

```
Dockerfile-go
Dockerfile-mysql
Dockerfile-py
deployment-nginx.yaml
deployment-redis.yaml
pod-nginx.yaml
pv-manual.yaml
pvc-manual.yaml
sc-local.yaml
statefulset-nginx.yaml
```

## What to Look For

**Dockerfile issues:**
- Secrets/credentials copied into the image (even if deleted later, they remain in a layer)
- `ARG` or `ENV` with hardcoded credentials
- Credentials passed as build args (visible in `docker history`)

**Kubernetes manifest issues:**
- Passwords hardcoded in `env.value` (not from a Secret)
- Secrets echoed/printed in container commands (`echo $PASSWORD`)
- Credentials in `args` or `command` fields

**Note:** "Running as root" is explicitly NOT a concern for this task.

## Common Findings Pattern

| File | Issue |
|------|-------|
| `Dockerfile-mysql` | Copies a credentials/secret file into the image (stays in layer even if deleted with RUN rm) |
| `deployment-redis.yaml` | `env.valueFrom.secretKeyRef` is OK, but the value is then echoed in the container command |
| `statefulset-nginx.yaml` | Password directly in `env.value` (plaintext in manifest, not from Secret) |

## Steps

```bash
# On cks9640
cd /opt/course/3/files

# Grep for common credential patterns in Dockerfiles
grep -iE '(password|secret|key|token|credential)' Dockerfile-*

# Check for COPY of sensitive files
grep -i 'COPY' Dockerfile-*

# Check for plaintext env values in manifests
grep -A2 'value:' *.yaml

# Check for echo of env vars in commands
grep -iE '(echo|print|cat).*\$' *.yaml
```

## Write Results

```bash
# Write filenames with issues (one per line)
cat > /opt/course/3/security-issues << 'EOF'
Dockerfile-mysql
deployment-redis.yaml
statefulset-nginx.yaml
EOF
```

## Verification

```bash
cat /opt/course/3/security-issues
```
