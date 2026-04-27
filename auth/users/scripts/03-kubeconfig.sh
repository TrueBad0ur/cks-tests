#!/bin/bash
# Step 3: Build a kubeconfig for alice
# She can use this file as KUBECONFIG to talk to the cluster

USERNAME="alice"
OUTDIR="$(dirname "$0")/../../tmp"
KUBECONFIG_OUT="$OUTDIR/${USERNAME}.kubeconfig"

# Get cluster info from current kubeconfig
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

kubectl config set-cluster "${CLUSTER_NAME}" \
  --server="${SERVER}" \
  --certificate-authority=<(echo "${CA_DATA}" | base64 -d) \
  --embed-certs=true \
  --kubeconfig="${KUBECONFIG_OUT}"

kubectl config set-credentials "${USERNAME}" \
  --client-certificate="$OUTDIR/${USERNAME}.crt" \
  --client-key="$OUTDIR/${USERNAME}.key" \
  --embed-certs=true \
  --kubeconfig="${KUBECONFIG_OUT}"

kubectl config set-context "${USERNAME}@${CLUSTER_NAME}" \
  --cluster="${CLUSTER_NAME}" \
  --user="${USERNAME}" \
  --namespace="auth-demo" \
  --kubeconfig="${KUBECONFIG_OUT}"

kubectl config use-context "${USERNAME}@${CLUSTER_NAME}" \
  --kubeconfig="${KUBECONFIG_OUT}"

echo "Kubeconfig created: ${KUBECONFIG_OUT}"
echo ""
echo "Test it:"
echo "  KUBECONFIG=${KUBECONFIG_OUT} kubectl get pods -n auth-demo"
echo "  KUBECONFIG=${KUBECONFIG_OUT} kubectl auth whoami"
