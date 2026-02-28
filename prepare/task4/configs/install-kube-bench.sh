#!/bin/bash
# Install kube-bench for CIS Benchmark checking

set -e

KUBEBENCH_VERSION="0.15.0"

echo "Downloading kube-bench ${KUBEBENCH_VERSION}..."
wget -q -O /tmp/kube-bench.tar.gz https://github.com/aquasecurity/kube-bench/releases/download/v${KUBEBENCH_VERSION}/kube-bench_${KUBEBENCH_VERSION}_linux_amd64.tar.gz

echo "Extracting..."
tar -xzf /tmp/kube-bench.tar.gz -C /tmp
chmod +x /tmp/kube-bench

echo "Done! kube-bench available at /tmp/kube-bench"
/tmp/kube-bench version
