#!/bin/bash
# Install SealedSecrets controller and kubeseal CLI for CKS Task 3

set -e

echo "Installing SealedSecrets controller..."
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.0/controller.yaml

echo "Waiting for controller to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets-controller -n kube-system --timeout=60s

echo "Installing kubeseal CLI..."
KUBESEAL_VERSION="0.27.0"
wget -q -O /tmp/kubeseal.tar.gz "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xzf /tmp/kubeseal.tar.gz -C /tmp
mv /tmp/kubeseal-bin /tmp/kubeseal 2>/dev/null || true
chmod +x /tmp/kubeseal

if [ ! -f "/tmp/kubeseal" ]; then
    echo "Error: kubeseal binary not found"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Fetching SealedSecrets public certificate..."
/tmp/kubeseal --fetch-cert -o "${SCRIPT_DIR}/sealed-secrets-cert.pem"

echo "Done! kubeseal available at /tmp/kubeseal"
