#!/bin/bash
# Q1 | SBOM — reference commands
# Node: ssh cks9640

mkdir -p /opt/course/1

# Step 1: Generate SPDX-JSON SBOM using bom (kubernetes-sigs/bom)
bom generate \
  --image registry.k8s.io/kube-apiserver:v1.31.0 \
  --format json \
  --output /opt/course/1/sbom1.json

# Step 2: Generate CycloneDX SBOM using trivy
trivy image \
  --format cyclonedx \
  --output /opt/course/1/sbom2.json \
  registry.k8s.io/kube-controller-manager:v1.31.0

# Step 3: Scan existing SBOM for vulnerabilities, output JSON report
trivy sbom \
  --format json \
  --output /opt/course/1/sbom_check_result.json \
  /opt/course/1/sbom_check.json
