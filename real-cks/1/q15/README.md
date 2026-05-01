# Q15 — Configure TLS on Ingress

Replace the default self-signed certificate on Ingress `secure` in namespace `team-pink`
with a specific TLS certificate.

## Files

| File | Purpose |
|---|---|
| `namespace.yaml` | Namespace `team-pink` |
| `backend.yaml` | Deployment + Service (nginx backend) |
| `ingress.yaml` | Ingress without TLS (initial state) |
| `ingress-tls.yaml` | Ingress with TLS configured (final state) |
| `tls.crt` | Self-signed cert for `secure-ingress.test` |
| `tls.key` | Private key |

## Setup

```bash
kubectl apply -f namespace.yaml
kubectl apply -f backend.yaml
kubectl apply -f ingress.yaml
```

## Solution

### Step 1 — Create TLS Secret from cert files

```bash
kubectl -n team-pink create secret tls tls-secret \
  --key tls.key \
  --cert tls.crt
```

### Step 2 — Apply Ingress with TLS

```bash
kubectl apply -f ingress-tls.yaml
```

Or edit in place:
```bash
kubectl -n team-pink edit ing secure
# Add under spec:
#   tls:
#     - hosts:
#         - secure-ingress.test
#       secretName: tls-secret
```

## Verification

Get the external IP assigned by MetalLB:

```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller
# EXTERNAL-IP = IP assigned by MetalLB
INGRESS_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -ojsonpath='{.status.loadBalancer.ingress[0].ip}')
```

Add to `/etc/hosts`:

```bash
echo "$INGRESS_IP secure-ingress.test" | sudo tee -a /etc/hosts
```

Check which certificate is served:

```bash
curl -kv https://secure-ingress.test/ 2>&1 | grep subject
# subject: CN=secure-ingress.test  ← our cert, not the default self-signed
```

## How it works

Without `spec.tls` — the Ingress controller serves its **default** self-signed certificate.

With `spec.tls` — the controller finds the Secret `tls-secret`, loads the cert/key,
and serves it for requests matching `secure-ingress.test`.

```
curl https://secure-ingress.test
      ↓
ingress-nginx (TLS termination)
  reads Secret tls-secret → serves tls.crt
      ↓ HTTP
api-backend pod
```

## Regenerate the certificate

```bash
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout tls.key \
  -out tls.crt \
  -days 365 \
  -subj "/CN=secure-ingress.test" \
  -addext "subjectAltName=DNS:secure-ingress.test"
```
