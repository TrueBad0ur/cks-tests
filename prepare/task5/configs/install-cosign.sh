#!/bin/bash
# Install Cosign for Task 5

set -e

COSIGN_VERSION="v2.2.4"

echo "Downloading Cosign ${COSIGN_VERSION}..."
wget -q -O /tmp/cosign "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"

chmod +x /tmp/cosign

echo "Done! Cosign available at /tmp/cosign"
/tmp/cosign version
