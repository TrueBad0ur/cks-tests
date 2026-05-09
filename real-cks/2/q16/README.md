# Q16 — Docker Image Attack Surface

Reduce the attack surface of the `image-verify` image and push as v2.

## Task

Edit `/opt/course/16/image/Dockerfile` (in-place, do not add lines) to:

1. Change base image: `alpine:3.20` → `alpine:3.22`
2. Remove `curl` from the `apk add` line
3. Update nginx version: `>=1.14.0` → `>=1.18.0`
4. Ensure `USER myuser` is set (run main process as non-root)

## Example diff

```diff
-FROM alpine:3.20
+FROM alpine:3.22

-RUN adduser -D myuser && \
-    apk add --no-cache nginx>=1.14.0 curl
+RUN adduser -D myuser && \
+    apk add --no-cache nginx>=1.18.0
```

`USER myuser` and `ENTRYPOINT` lines should remain as-is.

## Build, test, push

```bash
cd /opt/course/16/image

# Build v2
podman build -t <exam-registry>:5000/image-verify:v2 .

# Test locally
podman run <exam-registry>:5000/image-verify:v2

# Push
podman push <exam-registry>:5000/image-verify:v2
```

Run as user `candidate` (not root):
```bash
whoami   # should be candidate
```

## Update Deployment to use v2

```bash
kubectl -n team-clover set image deployment/image-verify \
  image-verify=<exam-registry>:5000/image-verify:v2

# Or edit directly
kubectl -n team-clover edit deployment image-verify
# Change image tag from v1 to v2

# Watch rollout
kubectl -n team-clover rollout status deployment/image-verify
```

## Verification

```bash
# Deployment uses v2
kubectl -n team-clover get deployment image-verify -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: <exam-registry>:5000/image-verify:v2

# Pod is running
kubectl -n team-clover get pods

# Confirm no curl in image
podman run --rm <exam-registry>:5000/image-verify:v2 which curl   # should fail
podman run --rm <exam-registry>:5000/image-verify:v2 nginx -v

# Process runs as myuser
podman run --rm <exam-registry>:5000/image-verify:v2 id
```

## Why these changes matter

| Change | Security benefit |
|--------|-----------------|
| `alpine:3.22` | Newer base with fewer known CVEs |
| Remove `curl` | Smaller attack surface, no outbound HTTP tool available |
| `nginx>=1.18.0` | Ensures patched nginx version |
| `USER myuser` | Process runs as non-root, limits damage from container escape |
