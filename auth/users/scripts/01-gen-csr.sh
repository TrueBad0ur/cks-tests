#!/bin/bash
# Step 1: Generate private key + CSR, then submit to Kubernetes
# CN = username, O = group (used for RBAC)

USERNAME="alice"
GROUP="developers"
OUTDIR="$(dirname "$0")/../../tmp"
mkdir -p "$OUTDIR"

# Generate private key
openssl genrsa -out "$OUTDIR/${USERNAME}.key" 2048

# Generate CSR (Certificate Signing Request)
openssl req -new \
  -key "$OUTDIR/${USERNAME}.key" \
  -out "$OUTDIR/${USERNAME}.csr" \
  -subj "/CN=${USERNAME}/O=${GROUP}"

# Submit CSR to Kubernetes
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USERNAME}
spec:
  request: $(base64 -w0 < "$OUTDIR/${USERNAME}.csr")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages:
  - client auth
EOF

echo ""
echo "CSR submitted. Pending approval:"
kubectl get csr "${USERNAME}"
echo ""
echo "Next: run 02-approve.sh"
