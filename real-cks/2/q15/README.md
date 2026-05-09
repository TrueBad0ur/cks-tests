# Q15 — Apiserver TLS Settings

Set minimum TLS version of the API server to TLS 1.3, then capture the curl error.

## Setup

### 1. Edit kube-apiserver manifest

```bash
sudo vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

Add to the `command` section:
```yaml
- --tls-min-version=VersionTLS13
```

The apiserver will automatically restart when the manifest changes. Wait for it:
```bash
watch crictl ps | grep apiserver
# Wait until you see it running again (a new container ID)
```

### 2. Verify apiserver is using TLS 1.3

```bash
# TLS 1.3 connection should succeed
curl -k --tlsv1.3 https://127.0.0.1:6443 2>&1 | head -5
```

## Capture curl output

```bash
mkdir -p /opt/course/15

curl --tls-max 1.2 --tlsv1.2 \
  https://127.0.0.1:6443 \
  --cacert /etc/kubernetes/pki/ca.crt \
  2>&1 > /opt/course/15/curl.log

cat /opt/course/15/curl.log
```

Expected output (TLS 1.2 rejected):
```
curl: (35) OpenSSL SSL_connect: Connection reset by peer in connection to 127.0.0.1:6443
```
or:
```
curl: (35) error:0A000410:SSL routines::ssl/tls alert handshake failure
```

The exact error message varies by curl/OpenSSL version. Either way, it should fail.

## Verification

```bash
# This should FAIL (TLS 1.2 rejected)
curl --tls-max 1.2 --tlsv1.2 https://127.0.0.1:6443 -k

# This should SUCCEED (TLS 1.3 works)
curl --tlsv1.3 https://127.0.0.1:6443 -k

# Check the log file exists and has content
cat /opt/course/15/curl.log
```

## Valid TLS version values

| Flag value | TLS version |
|-----------|-------------|
| `VersionTLS10` | TLS 1.0 |
| `VersionTLS11` | TLS 1.1 |
| `VersionTLS12` | TLS 1.2 |
| `VersionTLS13` | TLS 1.3 |

## Revert (if needed)

Remove `--tls-min-version` from the manifest to restore default (TLS 1.2+).
