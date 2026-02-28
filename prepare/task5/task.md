# Task 5: Image Security - Trivy

## Objective
Analyze container image security using Trivy.

## Pre-created Resources
- Dockerfile in `configs/Dockerfile`

## Tools
- Trivy is available at `/tmp/trivy`

## Your Task
Analyze the image security and answer in `solution.md`:

### Question 1
Scan `nginx:1.19.0` for vulnerabilities using Trivy.
- How many Critical, High, Medium, Low vulnerabilities?

### Question 2
Scan `nginx:1.25` and compare:
- How many vulnerabilities does it have?
- Show the diff between Critical vulnerabilities in 1.19.0 and 1.25.

### Question 3
Scan the Dockerfile in `configs/Dockerfile` using Trivy config.
- What security issues did you find?

### Question 4
Generate an SBOM for `nginx:1.25` in SPDX format.
- List the packages found in the image.

### Question 5
Install Cosign using `configs/install-cosign.sh`
Generate a Cosign key pair.

### Question 6
Sign an image using Cosign: `/tmp/cosign sign --key cosign.key nginx:1.25`

### Question 7
Verify the signature: `/tmp/cosign verify --key cosign.pub nginx:1.25`
