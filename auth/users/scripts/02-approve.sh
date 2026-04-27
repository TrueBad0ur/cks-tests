#!/bin/bash
# Step 2: Approve the CSR and extract the signed certificate

USERNAME="alice"
OUTDIR="$(dirname "$0")/../../tmp"

# Approve (only cluster-admin can do this)
kubectl certificate approve "${USERNAME}"

# Wait for certificate to be issued
echo "Waiting for certificate..."
for i in $(seq 1 10); do
  CERT=$(kubectl get csr "${USERNAME}" -o jsonpath='{.status.certificate}' 2>/dev/null)
  if [ -n "$CERT" ]; then
    break
  fi
  sleep 1
done

# Save the signed certificate
kubectl get csr "${USERNAME}" \
  -o jsonpath='{.status.certificate}' | base64 -d > "$OUTDIR/${USERNAME}.crt"

echo "Certificate saved to ${USERNAME}.crt"
echo ""
echo "CN and issuer:"
openssl x509 -in "$OUTDIR/${USERNAME}.crt" -noout -subject -issuer

echo ""
echo "Next: run 03-kubeconfig.sh"
