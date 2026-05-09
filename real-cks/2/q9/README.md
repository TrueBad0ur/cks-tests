# Q9 — Certificates and Signing Requests

Approve one CSR, deny another, and create a third from a raw .csr file.

## Task 1 — Approve CSR from csr-app-6c63ce3f.yaml

```bash
kubectl apply -f /opt/course/9/csr-app-6c63ce3f.yaml
kubectl get csr

# Approve it
kubectl certificate approve app-6c63ce3f

# Download the signed certificate (base64-decode)
kubectl get csr app-6c63ce3f -o jsonpath='{.status.certificate}' | base64 -d > /opt/course/9/app-6c63ce3f.crt

# Verify
openssl x509 -in /opt/course/9/app-6c63ce3f.crt -noout -text | head -20
```

## Task 2 — Deny CSR from csr-app-dc6fdc2d.yaml

```bash
kubectl apply -f /opt/course/9/csr-app-dc6fdc2d.yaml
kubectl get csr

# Deny it
kubectl certificate deny app-dc6fdc2d

# Store kubectl describe output
kubectl describe csr app-dc6fdc2d > /opt/course/9/csr-app-dc6fdc2d.log

cat /opt/course/9/csr-app-dc6fdc2d.log
```

## Task 3 — Create CSR yaml from /opt/course/9/new.csr

### Extract the CN (will be the CSR NAME)

```bash
CN=$(openssl req -in /opt/course/9/new.csr -noout -subject | sed 's/.*CN\s*=\s*//' | sed 's/,.*//' | tr -d ' ')
echo "CN: $CN"
```

### Base64-encode the CSR content

```bash
REQUEST=$(cat /opt/course/9/new.csr | base64 | tr -d "\n")
```

### Generate the YAML

```bash
cat > /opt/course/9/new.csr.yaml << EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $CN
spec:
  groups:
  - system:authenticated
  request: $REQUEST
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

cat /opt/course/9/new.csr.yaml
```

## Verification

```bash
# Task 1
openssl x509 -in /opt/course/9/app-6c63ce3f.crt -noout -dates

# Task 2
grep -i "denied\|condition" /opt/course/9/csr-app-dc6fdc2d.log

# Task 3
kubectl apply -f /opt/course/9/new.csr.yaml --dry-run=client
grep "name:" /opt/course/9/new.csr.yaml   # should match CN
```

## Notes

- CSR NAME must exactly match the CN from the .csr file
- `base64 | tr -d "\n"` removes newlines — required for the request field
- `kubectl certificate approve/deny` requires `certificates.k8s.io` API group permissions
- After approval, the certificate may take a moment to appear in `.status.certificate`
