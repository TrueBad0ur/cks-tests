# Q1 — SBOM Generation and Vulnerability Scanning

Generate Software Bill of Materials documents and scan for vulnerabilities.

## Tasks

1. `bom` → SPDX-JSON SBOM of `registry.k8s.io/kube-apiserver:v1.31.0`
2. `trivy` → CycloneDX SBOM of `registry.k8s.io/kube-controller-manager:v1.31.0`
3. `trivy` → scan existing SBOM at `/opt/course/1/sbom_check.json` for vulnerabilities

## Commands

### 1. Generate SPDX-JSON with bom

```bash
bom generate \
  --image registry.k8s.io/kube-apiserver:v1.31.0 \
  --format spdx-json \
  --output /opt/course/1/sbom1.json
```

### 2. Generate CycloneDX with trivy

```bash
trivy image \
  --format cyclonedx \
  --output /opt/course/1/sbom2.json \
  registry.k8s.io/kube-controller-manager:v1.31.0
```

### 3. Scan existing SBOM for vulnerabilities

```bash
trivy sbom \
  --format json \
  --output /opt/course/1/sbom_check_result.json \
  /opt/course/1/sbom_check.json
```

## Verification

```bash
# Check SBOM format
python3 -m json.tool /opt/course/1/sbom1.json | head -20
python3 -m json.tool /opt/course/1/sbom2.json | head -20

# Check scan result has vulnerabilities section
cat /opt/course/1/sbom_check_result.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('Results:', len(d.get('Results', [])))"
```

## Key Flags

| Tool | Format flag | Format value |
|------|------------|--------------|
| bom  | `--format` | `spdx-json` |
| trivy image | `--format` | `cyclonedx` |
| trivy sbom  | `--format` | `json` |

## Notes

- `bom generate --image` pulls the image and generates SBOM from its layers
- `trivy sbom` accepts SPDX or CycloneDX as input
- Both `sbom1.json` and `sbom_check_result.json` must be valid JSON — verify with python3
