#!/bin/bash
# Install Trivy for CKS Task 5

set -e

TRIVY_VERSION="0.57.1"

echo "Downloading Trivy ${TRIVY_VERSION}..."
wget -q -O /tmp/trivy.tar.gz "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"

echo "Extracting..."
tar -xzf /tmp/trivy.tar.gz -C /tmp

echo "Done! Trivy available at /tmp/trivy"
/tmp/trivy --version
