# CKS Practice — Kubernetes 1.34

Each question is solved on a specific node via `ssh`. Use `sudo -i` to become root where needed.

---

## Question 1 | SBOM

**Node:** `ssh cks9640`

1. Generate an SPDX-JSON SBOM of `registry.k8s.io/kube-apiserver:v1.31.0` using `bom` → `/opt/course/1/sbom1.json`
2. Generate a CycloneDX SBOM of `registry.k8s.io/kube-controller-manager:v1.31.0` using `trivy` → `/opt/course/1/sbom2.json`
3. Scan the existing SPDX-JSON SBOM at `/opt/course/1/sbom_check.json` for vulnerabilities with `trivy`, save JSON result → `/opt/course/1/sbom_check_result.json`

See: [`q1/commands.sh`](q1/commands.sh)

### Solution

```bash
mkdir -p /opt/course/1

# Step 1 — bom (kubernetes-sigs/bom) generates SPDX-JSON by default with --format json
bom generate \
  --image registry.k8s.io/kube-apiserver:v1.31.0 \
  --format json \
  --output /opt/course/1/sbom1.json

# Step 2 — trivy generates CycloneDX format
trivy image \
  --format cyclonedx \
  --output /opt/course/1/sbom2.json \
  registry.k8s.io/kube-controller-manager:v1.31.0

# Step 3 — scan an existing SBOM file for CVEs, output JSON
trivy sbom \
  --format json \
  --output /opt/course/1/sbom_check_result.json \
  /opt/course/1/sbom_check.json
```

Key concepts:
- `bom` is the Kubernetes SPDX tool (`kubernetes-sigs/bom`). Use `--format json` for SPDX-JSON output.
- `trivy image --format cyclonedx` produces a CycloneDX SBOM instead of the default vulnerability report.
- `trivy sbom` takes an existing SBOM file as input and scans it for vulnerabilities. The `--format json` flag controls the output report format (not the input SBOM format).
- SPDX and CycloneDX are the two dominant SBOM standards. SPDX is SPDX-JSON; CycloneDX is JSON-based.

---

## Question 2 | Runtime Security with Falco

**Node:** `ssh cks5632` (control plane), Falco runs on `ssh cks5632-node1` (worker)

Falco is installed on worker node `cks5632-node1`. Custom rules are at `/etc/falco/rules.d/falco_custom.yaml`.

**Task 1:** Find the Pod running image `httpd` that modifies `/etc/passwd`. Scale its Deployment down to 0 replicas.

**Task 2:** Find the Pod running image `nginx` that triggers rule `Package management process launched`. Update the rule's output to include only: `time-with-nanoseconds`, `container-id`, `container-name`, `user-name`. Collect Falco logs for 20 seconds, save to `/opt/course/2/falco.log` on `cks5632`. Scale its Deployment down to 0 replicas.

See: [`q2/falco-custom.yaml`](q2/falco-custom.yaml)

### Solution

```bash
# On cks5632-node1
sudo -i

# Task 1: find which pod running httpd is writing /etc/passwd
# Look for a rule like "File Below /etc Modified" or check running containers
crictl ps | grep httpd
# Pod found: rating-service in namespace team-violet

# Scale down from the control plane (cks5632):
k -n team-violet scale deploy rating-service --replicas=0

# Task 2: find the nginx pod triggering "Package management process launched"
# Inspect current falco rule output format
cat /etc/falco/rules.d/falco_custom.yaml

# Update the output line for "Package management process launched" rule
# Only edit the output field — no new lines allowed
vim /etc/falco/rules.d/falco_custom.yaml
# Change output to: Package management process launched %evt.time,%container.id,%container.name,%user.name

# Collect logs for 20 seconds
falco -r /etc/falco/rules.d/falco_custom.yaml 2>&1 | timeout 20 cat > /tmp/falco.log

# Copy to control plane
# On cks5632:
scp cks5632-node1:/tmp/falco.log /opt/course/2/falco.log

# Scale down the nginx deployment (found: webapi in namespace team-clover)
k -n team-clover scale deploy webapi --replicas=0
```

Falco field names for the output format:
| Task field name          | Falco field            |
|--------------------------|------------------------|
| `time-with-nanoseconds`  | `%evt.time`            |
| `container-id`           | `%container.id`        |
| `container-name`         | `%container.name`      |
| `user-name`              | `%user.name`           |

Updated rule output line:
```yaml
output: >
  Package management process launched %evt.time,%container.id,%container.name,%user.name
```

**Key concepts:**
- Falco reads rules from `/etc/falco/rules.d/` in addition to the default rules file.
- Use `crictl ps` (not `docker ps`) — Kubernetes uses containerd, not Docker.
- The task says "edit existing lines only — no new lines". Only modify the `output:` line value.
- Falco output fields use `%field.name` syntax inside the output string.

---

## Question 3 | Manual Static Security Analysis

**Node:** `ssh cks9640`

Files at `/opt/course/3/files`. Manually inspect for credential exposure issues. Write the names of files with security issues to `/opt/course/3/security-issues` (one filename per line, no path).

See the files in: [`q3/`](q3/)

### Solution

```bash
ls /opt/course/3/files
# Dockerfile-go  Dockerfile-mysql  Dockerfile-py  deployment-nginx.yaml
# deployment-redis.yaml  pod-nginx.yaml  pv-manual.yaml  pvc-manual.yaml
# sc-local.yaml  statefulset-nginx.yaml

# Review each file looking for:
# - Secrets in Docker layers (COPY secret → use → DELETE: the secret is still in intermediate layer)
# - Secrets echoed to stdout/logs via command args
# - Hardcoded passwords in env vars

cat /opt/course/3/files/Dockerfile-mysql
# ISSUE: COPYs secret-token into the image, uses it, then RMs it
# The COPY creates a layer that permanently contains the secret

cat /opt/course/3/files/deployment-redis.yaml
# ISSUE: command args echo $SECRET_USERNAME and $SECRET_PASSWORD to logs

cat /opt/course/3/files/statefulset-nginx.yaml
# ISSUE: hardcoded Password: MyDiReCtP@sSw0rd in env vars

# Write results
cat > /opt/course/3/security-issues << 'EOF'
Dockerfile-mysql
deployment-redis.yaml
statefulset-nginx.yaml
EOF
```

**Issues found:**

1. **`Dockerfile-mysql`** — Multi-layer secret leak. The Dockerfile COPYs a `secret-token` file, uses it (e.g. for a build step), then RMs it — but Docker layering means the COPY layer permanently stores the secret in the image. Fix: use build-time secrets (`--secret`) or multi-stage builds.

2. **`deployment-redis.yaml`** — Credentials echoed to logs. The container `command` or `args` field contains something like `["sh", "-c", "echo $SECRET_USERNAME:$SECRET_PASSWORD && ..."]`. Anything echoed to stdout is captured in container logs — accessible to anyone with `kubectl logs`.

3. **`statefulset-nginx.yaml`** — Hardcoded password in plain text. The env var section contains `Password: MyDiReCtP@sSw0rd` directly in the manifest. Credentials should never be hardcoded — use Secrets with `valueFrom.secretKeyRef`.

**Files without issues:** `Dockerfile-go`, `Dockerfile-py`, `deployment-nginx.yaml`, `pod-nginx.yaml`, `pv-manual.yaml`, `pvc-manual.yaml`, `sc-local.yaml`

---

## Question 4 | Pod Security Standard

**Node:** `ssh cks6032`

Deployment `container-host-hacker` in namespace `team-rose` mounts `/run/containerd` as a `hostPath` volume. Add the PSS `baseline` enforce label to the namespace. Delete the existing Pod (let the ReplicaSet try to recreate it — it will fail). Capture the ReplicaSet failure event lines to `/opt/course/4/logs`.

See: [`q4/namespace-team-rose.yaml`](q4/namespace-team-rose.yaml), [`q4/deployment-container-host-hacker.yaml`](q4/deployment-container-host-hacker.yaml)

### Solution

```bash
# Add PSS enforce label to namespace
k label ns team-rose pod-security.kubernetes.io/enforce=baseline

# Verify the deployment exists and see what it does
k -n team-rose get deploy container-host-hacker -oyaml | grep -A5 hostPath

# Delete the Pod (ReplicaSet will try to recreate it — and fail)
k -n team-rose delete pod -l app=container-host-hacker

# Check ReplicaSet events showing the violation
k -n team-rose get events | grep FailedCreate
# Expected:
# Warning  FailedCreate  replicaset-controller  Error creating: pods "container-host-hacker-dbf989777-..." 
#   is forbidden: violates PodSecurity "baseline:latest": hostPath volumes (volume "containerdata")

# Save the event lines
k -n team-rose get events | grep FailedCreate > /opt/course/4/logs
```

**Key concepts:**
- PSS `baseline` forbids `hostPath` volumes — the Pod creation by the ReplicaSet is rejected.
- The enforce label format: `pod-security.kubernetes.io/enforce=<level>` where level is `privileged`, `baseline`, or `restricted`.
- You need to delete the existing Pod — the label only affects NEW Pod creation. Existing Pods are not evicted when the label is added.
- The ReplicaSet controller logs the `FailedCreate` Warning event that contains the violation reason.
- `hostPath` mounts are dangerous because they give container access to node filesystem paths (here: the containerd socket directory).

---

## Question 5 | Network Policy

**Node:** `ssh cks4933`

Existing NetworkPolicy `api-private-access` in NS `team-ivy-private` controls ingress to Pods with label `id=api-private`:
- Port 3000: requires label `api-access-operation: "true"` on source Pod
- Port 4000: requires label `api-access-status: "true"` on source Pod
- Port 5000: requires label `api-access-report: "true"` on source Pod

Tasks:
1. Add label `api-access-operation: "true"` to Deployment `gateway-v1` in `team-ivy-gateway` (grants port 3000 access)
2. Add labels `api-access-status: "true"` and `api-access-report: "true"` to Deployment `gateway-v2` in `team-ivy-gateway` (grants ports 4000 and 5000 access)
3. Create NetworkPolicies in `team-ivy-gateway` to restrict egress of `gateway-v1` and `gateway-v2` so they can only egress to `team-ivy-private` namespace

See: [`q5/existing-network-policy.yaml`](q5/existing-network-policy.yaml), [`q5/gateway-v1-deployment.yaml`](q5/gateway-v1-deployment.yaml), [`q5/gateway-v2-deployment.yaml`](q5/gateway-v2-deployment.yaml), [`q5/network-policies.yaml`](q5/network-policies.yaml)

### Solution

```bash
# Task 1: label gateway-v1 deployment (labels go on pod template so pods inherit them)
k -n team-ivy-gateway patch deploy gateway-v1 \
  --patch '{"spec":{"template":{"metadata":{"labels":{"api-access-operation":"true"}}}}}'

# Task 2: label gateway-v2 deployment
k -n team-ivy-gateway patch deploy gateway-v2 \
  --patch '{"spec":{"template":{"metadata":{"labels":{"api-access-status":"true","api-access-report":"true"}}}}}'

# Task 3: create egress-restricting NetworkPolicies
k apply -f q5/network-policies.yaml

# Verify connectivity
k -n team-ivy-gateway exec <gateway-v1-pod> -- curl team-ivy-private-service:3000  # should work
k -n team-ivy-gateway exec <gateway-v1-pod> -- curl google.com  # should fail (blocked egress)
```

**Key concepts:**
- Labels for NetworkPolicy selection must be on the **Pod template** (`spec.template.metadata.labels`), not on the Deployment itself.
- When restricting egress to a namespace, use `namespaceSelector` with the target namespace's labels (e.g., `kubernetes.io/metadata.name: team-ivy-private`).
- The existing ingress policy in `team-ivy-private` already handles the "who can talk to api-private". The new egress policies in `team-ivy-gateway` enforce the source side.
- DNS egress (port 53 UDP/TCP) must be explicitly allowed in an egress-restricting NetworkPolicy or DNS resolution breaks.

---

## Question 6 | Verify Platform Binaries

**Node:** `ssh cks1428`

Binaries at `/opt/course/6/binaries`. Verify each against the provided sha512 hashes. Delete any that do not match.

See: [`q6/hashes.txt`](q6/hashes.txt)

### Solution

```bash
cd /opt/course/6/binaries

sha512sum kube-apiserver
# Expected: f417c0555bc0167355589dd1afe23be9bf909bf98312b1025f12015d1b58a1c62c9908c0067a7764fa35efdac7016a9efa8711a44425dd6692906a7c283f032c
# Compare manually — if match: OK

sha512sum kube-controller-manager
# Expected: 60100cc725e91fe1a949e1b2d0474237844b5862556e25c2c655a33boa8225855ec5ee22fa4927e6c46a60d43a7c4403a27268f96fbb726307d1608b44f38a60
# NOTE: the expected hash contains 'boa' — this is a typo in the exam (should be 'b0a')
# The actual sha512sum output will differ → DELETE this binary

sha512sum kube-proxy
# Expected: 52f9d8ad045f8eee1d689619ef8ceef2d86d50c75a6a332653240d7ba5b2a114aca056d9e513984ade24358c9662714973c1960c62a5cb37dd375631c8a614c6
# Compare — if match: OK

sha512sum kubelet
# Expected: 4be40f2440619e990897cf956c32800dc96c2c983bf64519854a3309fa5aa21827991559f9c44595098e27e6f2ee4d64a3fdec6baba8a177881f20e3ec61e26c
# Hash differs → DELETE this binary

# Delete the mismatched binaries
rm /opt/course/6/binaries/kubelet
rm /opt/course/6/binaries/kube-controller-manager
```

**Binaries to delete:**
- `kubelet` — hash does not match (different binary)
- `kube-controller-manager` — hash does not match (provided expected hash contains typo `boa` vs `b0a`)

**Key concepts:**
- `sha512sum <file>` computes the SHA-512 hash. Compare character by character.
- The exam may include subtle typos in expected hashes (e.g., letter `o` instead of digit `0`) — the actual binary hash will not match either way.
- Always verify platform binaries after download from any source (even official k8s.io) to ensure supply chain integrity.

---

## Question 7 | KubeletConfiguration

**Node:** `ssh cks9640` (controlplane), also apply to `cks9640-node1`

Using the kubeadm method (edit the `kubelet-config` ConfigMap in `kube-system`), configure:
- `containerLogMaxSize: 5Mi`
- `containerLogMaxFiles: 3`

Apply to both nodes.

See: [`q7/kubelet-config-patch.yaml`](q7/kubelet-config-patch.yaml)

### Solution

```bash
# Edit the ConfigMap that kubeadm uses as the source of truth
k -n kube-system edit cm kubelet-config
# Under the `kubelet:` key, add:
#   containerLogMaxSize: 5Mi
#   containerLogMaxFiles: 3

# Apply to controlplane node cks9640
kubeadm upgrade node phase kubelet-config
systemctl restart kubelet
# Verify
cat /var/lib/kubelet/config.yaml | grep -E 'containerLog'

# Apply to worker node cks9640-node1
ssh cks9640-node1
sudo -i
kubeadm upgrade node phase kubelet-config
systemctl restart kubelet
cat /var/lib/kubelet/config.yaml | grep -E 'containerLog'
```

**Key concepts:**
- Kubeadm manages kubelet config via the `kubelet-config` ConfigMap in `kube-system`.
- `kubeadm upgrade node phase kubelet-config` pulls the ConfigMap and writes it to `/var/lib/kubelet/config.yaml`.
- After pulling new config, kubelet must be restarted: `systemctl restart kubelet`.
- The `containerLogMaxSize` field accepts Kubernetes quantity strings (e.g., `5Mi`, `100Mi`).
- `containerLogMaxFiles` is an integer — the maximum number of log files kept per container.
- This is the **recommended way** — editing `/var/lib/kubelet/config.yaml` directly on each node would work but bypasses the ConfigMap source of truth and would be overwritten on the next `kubeadm upgrade node phase kubelet-config`.

---

## Question 8 | CiliumNetworkPolicy

**Node:** `ssh cks6032`

Namespace `team-iris`. An existing `default-allow` CiliumNetworkPolicy allows all intra-namespace traffic and DNS. Create 3 additional policies:

- **p1** (Layer 3): Deny egress from `type=messenger` Pods to `type=database` Pods
- **p2** (Layer 4): Deny ICMP (type 8 / EchoRequest) from `type=transmitter` Pods to `type=database` Pods
- **p3** (Layer 3 + mTLS): Enable mutual TLS (`authentication.mode: required`) for egress from `type=database` Pods to `type=messenger` Pods

Existing workloads in `team-iris`:
- StatefulSet `database` (label: `type=database`), Service `database` port 80
- Deployment `messenger` (2 replicas, label: `type=messenger`)
- Deployment `transmitter` (2 replicas, label: `type=transmitter`)

See: [`q8/default-allow.yaml`](q8/default-allow.yaml), [`q8/p1.yaml`](q8/p1.yaml), [`q8/p2.yaml`](q8/p2.yaml), [`q8/p3.yaml`](q8/p3.yaml), [`q8/workloads.yaml`](q8/workloads.yaml)

### Solution

```bash
k apply -f q8/p1.yaml
k apply -f q8/p2.yaml
k apply -f q8/p3.yaml

# Verify p1: messenger cannot reach database
k -n team-iris exec <messenger-pod> -- curl database  # should fail (connection refused / timeout)

# Verify p2: transmitter cannot ICMP-ping database but TCP still works
k -n team-iris exec <transmitter-pod> -- ping database  # should fail
k -n team-iris exec <transmitter-pod> -- curl database  # should succeed (p2 only blocks ICMP)

# Verify p3: database can reach messenger, Cilium handles mTLS
k -n team-iris exec <database-pod> -- curl messenger  # should work with mTLS enforced by Cilium
```

**Key concepts:**
- `egressDeny` takes precedence over `egress` allow rules in Cilium — even the `default-allow` policy's allow is overridden.
- The ICMP type `8` = EchoRequest for IPv4; `EchoRequest` is the named alias for IPv6.
- `authentication.mode: required` triggers Cilium's SPIFFE/mTLS mutual authentication — no cert management needed in the app, Cilium handles it transparently.
- `egressDeny` for Layer 3 denies all traffic (any protocol/port) from source to destination endpoint.
- For Layer 4 ICMP deny (p2), only ICMP is blocked — TCP/UDP traffic to the same destination still flows.

---

## Question 9 | Certificates and Signing Requests

**Node:** `ssh cks7984`

1. Create and **approve** the CSR from `/opt/course/9/csr-app-6c63ce3f.yaml`. Download the issued certificate to `/opt/course/9/app-6c63ce3f.crt`.
2. Create and **deny** the CSR from `/opt/course/9/csr-app-dc6fdc2d.yaml`. Save `kubectl describe` output to `/opt/course/9/csr-app-dc6fdc2d.log`.
3. From the CSR file `/opt/course/9/new.csr`, create a `CertificateSigningRequest` YAML with CN `app-c5a95f65@users-company`. Store it at `/opt/course/9/new.csr.yaml`.

See: [`q9/csr-template.yaml`](q9/csr-template.yaml), [`q9/new-csr.yaml`](q9/new-csr.yaml)

### Solution

```bash
# Step 1: approve CSR
k apply -f /opt/course/9/csr-app-6c63ce3f.yaml
k certificate approve app-6c63ce3f@users-pro

# Download the issued certificate
k get csr app-6c63ce3f@users-pro \
  -ojsonpath="{.status.certificate}" | base64 -d > /opt/course/9/app-6c63ce3f.crt

# Step 2: deny CSR
k apply -f /opt/course/9/csr-app-dc6fdc2d.yaml
k certificate deny app-dc6fdc2d@users-base

k describe csr app-dc6fdc2d@users-base > /opt/course/9/csr-app-dc6fdc2d.log

# Step 3: build CSR YAML from raw .csr file
# Inspect the CSR to confirm CN
openssl req -in /opt/course/9/new.csr -noout -text | grep Subject

# Base64-encode the CSR content (no line breaks)
CSR_B64=$(cat /opt/course/9/new.csr | base64 | tr -d "\n")

# Write the CertificateSigningRequest manifest
cat > /opt/course/9/new.csr.yaml << EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: app-c5a95f65@users-company
spec:
  groups:
  - system:authenticated
  request: ${CSR_B64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
```

**Key concepts:**
- `kubectl certificate approve <name>` sets the `Approved` condition; `deny` sets `Denied`.
- The issued certificate is only available in `.status.certificate` after approval — it is base64-encoded.
- The `request` field in the CSR manifest must be the base64-encoded PEM of the CSR with no newlines (`tr -d "\n"`).
- `signerName: kubernetes.io/kube-apiserver-client` is for client auth certificates (used to authenticate to the API server).
- `usages: [client auth]` is required for this signer.

---

## Question 10 | Istio Security and mTLS

**Node:** `ssh cks1428`

Namespace `team-sedum` has Deployments `one` and `two`. Istio is installed in `istio-system`. Enable sidecar injection so both Deployments get the Istio proxy sidecar.

See: [`q10/namespace.yaml`](q10/namespace.yaml), [`q10/deployments.yaml`](q10/deployments.yaml)

### Solution

```bash
# Enable Istio sidecar injection for the namespace
k label ns team-sedum istio-injection=enabled

# Restart both deployments so new pods are created with the sidecar
k -n team-sedum rollout restart deploy one two

# Verify: pods should show 2/2 READY (app container + istio-proxy)
k -n team-sedum get pods
# NAME                   READY   STATUS    RESTARTS
# one-xxxx-yyyy          2/2     Running   0
# two-xxxx-yyyy          2/2     Running   0

# Verify sidecar container is istio-proxy
k -n team-sedum get pod <one-pod> -ojsonpath='{.spec.containers[*].name}'
# app istio-proxy
```

**Key concepts:**
- Istio sidecar injection is enabled per-namespace with the label `istio-injection=enabled`.
- Existing Pods must be restarted — the label only affects newly created Pods.
- After injection, each Pod has 2 containers: the application container and `istio-proxy` (Envoy).
- Istio's mTLS (STRICT mode) requires both sides to have the sidecar. Without injection, mutual TLS cannot be enforced.
- The Istio control plane (`istiod`) watches for the namespace label and configures the injector webhook automatically.

---

## Question 11 | Secrets in ETCD

**Node:** `ssh cks4933`

Secret `database-access` in namespace `team-daisy`.

1. Read the Secret directly from ETCD (bypassing the API server) using `etcdctl`. Save the raw output to `/opt/course/11/etcd-secret-content`.
2. Decode the base64 value of key `pass` from that Secret. Save the plaintext to `/opt/course/11/database-password`.

See: [`q11/secret.yaml`](q11/secret.yaml)

### Solution

```bash
sudo -i

# Read Secret directly from etcd
ETCDCTL_API=3 etcdctl \
  --cert /etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key /etc/kubernetes/pki/apiserver-etcd-client.key \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  get /registry/secrets/team-daisy/database-access \
  > /opt/course/11/etcd-secret-content

cat /opt/course/11/etcd-secret-content

# Decode the 'pass' value
# The Secret stores base64-encoded values; etcd stores the API object which itself
# contains the base64. So the raw etcd content shows the double-encoded value.
# Use kubectl to get the properly decoded value:
k -n team-daisy get secret database-access \
  -ojsonpath='{.data.pass}' | base64 -d > /opt/course/11/database-password

cat /opt/course/11/database-password
# confidential
```

**Key concepts:**
- ETCD key path format: `/registry/{resource-type}/{namespace}/{name}` e.g. `/registry/secrets/team-daisy/database-access`
- Secrets stored in ETCD without encryption at rest are **not** encrypted — they are base64-encoded (encoding, not encryption). Anyone with ETCD access can read them.
- The etcdctl certs are at `/etc/kubernetes/pki/apiserver-etcd-client.{crt,key}` and `/etc/kubernetes/pki/etcd/ca.crt`.
- `ETCDCTL_API=3` must be set — ETCD v3 API is required for Kubernetes.
- To enable encryption at rest, use an `EncryptionConfiguration` and the `--encryption-provider-config` apiserver flag (see exam 3, Q14).

---

## Question 12 | Hack Secrets

**Node:** `ssh cks1428`

Context `restricted@workload-prod`, user `restricted` in namespace `restricted`. The user cannot `list` or `get` Secrets but can `exec` into Pods. Find the values of `secret1`, `secret2`, `secret3`.

See: [`q12/pods.yaml`](q12/pods.yaml), [`q12/secrets.yaml`](q12/secrets.yaml), [`q12/rbac.yaml`](q12/rbac.yaml)

### Solution

```bash
k config use-context restricted@workload-prod

# Check what we can do
k -n restricted auth can-i --list

# List pods (we can do this)
k -n restricted get pods
# pod1, pod2, pod3

# secret1: pod1 has the secret mounted as a volume at /etc/secret-volume/password
k -n restricted exec pod1 -- cat /etc/secret-volume/password
# you-are

# secret2: pod2 has the secret as an environment variable named PASSWORD
k -n restricted exec pod2 -- env | grep PASSWORD
# PASSWORD=an-amazing

# secret3: pod3 has a ServiceAccount with permission to GET secrets
# Use its mounted token to call the API server
k -n restricted exec pod3 -- sh -c '
  curl -sk \
    -H "Authorization: Bearer $(cat /run/secrets/kubernetes.io/serviceaccount/token)" \
    https://kubernetes.default/api/v1/namespaces/restricted/secrets
' | grep -A2 secret3
# value: pEnEtRaTiOn-tEsTeR (base64 decode it)

# or decode inline:
k -n restricted exec pod3 -- sh -c '
  TOKEN=$(cat /run/secrets/kubernetes.io/serviceaccount/token)
  curl -sk -H "Authorization: Bearer $TOKEN" \
    https://kubernetes.default/api/v1/namespaces/restricted/secrets/secret3 \
  | python3 -c "import sys,json,base64; d=json.load(sys.stdin); print(base64.b64decode(d[\"data\"][\"password\"]).decode())"
'
# pEnEtRaTiOn-tEsTeR
```

**Secret values:**
- `secret1` = `you-are`
- `secret2` = `an-amazing`
- `secret3` = `pEnEtRaTiOn-tEsTeR`

**Key concepts:**
- Even without `get`/`list` on Secrets, if a Pod mounts a secret as a volume, `exec` into the Pod exposes it.
- Env var secrets are visible via `env` inside the container.
- If a Pod's ServiceAccount has `get`/`list` on Secrets, the SA token (auto-mounted at `/run/secrets/kubernetes.io/serviceaccount/token`) can be used to query the API directly from inside the Pod.
- `automountServiceAccountToken: true` (default) means pod3 has the token available without any extra config.

---

## Question 13 | RBAC Operator

**Node:** `ssh cks4933`

Operator `cert-signer` (StatefulSet in NS `team-lilac`, SA `cert-signer`) is crashing because it lacks RBAC permissions. The operator runs these commands:

```bash
kubectl get configmap                   # needs: list configmaps in team-lilac
kubectl get configmap cert-signer-lock  # needs: get configmaps in team-lilac
kubectl get csr                         # needs: list CertificateSigningRequests (cluster-scope)
kubectl certificate approve request1    # needs: update certificatesigningrequests/approval
```

Fix by creating the required RBAC resources.

See: [`q13/role.yaml`](q13/role.yaml), [`q13/rolebinding.yaml`](q13/rolebinding.yaml), [`q13/clusterrole.yaml`](q13/clusterrole.yaml), [`q13/clusterrolebinding.yaml`](q13/clusterrolebinding.yaml)

### Solution

```bash
# Check why it's crashing
k -n team-lilac logs statefulset/cert-signer
# Error: configmaps is forbidden: User "system:serviceaccount:team-lilac:cert-signer" cannot list...

# Create Role for configmap access (namespace-scoped)
k apply -f q13/role.yaml
k apply -f q13/rolebinding.yaml

# Create ClusterRole for CSR access + approval (cluster-scoped)
k apply -f q13/clusterrole.yaml
k apply -f q13/clusterrolebinding.yaml

# Restart StatefulSet to pick up new permissions
k -n team-lilac rollout restart statefulset cert-signer

# Verify it starts up
k -n team-lilac get pods
k -n team-lilac logs statefulset/cert-signer
```

**Key concepts:**
- `kubectl certificate approve` updates the `certificatesigningrequests/approval` subresource — this is a separate resource from `certificatesigningrequests` itself. Both `list` (for `get csr`) and `update` on the subresource are needed.
- ConfigMap access is namespace-scoped → use Role + RoleBinding.
- CSR access is cluster-scoped → use ClusterRole + ClusterRoleBinding.
- The `update` verb on `certificatesigningrequests/approval` is specifically what `kubectl certificate approve` calls.

---

## Question 14 | Syscall Activity

**Node:** `ssh cks5632` → `ssh cks5632-node1`

Namespace `team-tulip`. Deployments: `collector1` (2 replicas), `collector2` (1 replica), `collector3` (2 replicas). Find which Deployment uses the `kill` syscall. Scale it down to 0.

See: [`q14/deployments.yaml`](q14/deployments.yaml)

### Solution

```bash
# On cks5632-node1 (worker node where the pods run)
ssh cks5632-node1
sudo -i

# Find the PIDs of all collector pods
crictl ps | grep collector

# Attach strace to each process to watch syscalls
# For each container, find its main PID via:
crictl inspect <container-id> | grep pid

# strace the PIDs, look for 'kill' syscall
strace -p <pid-of-collector1-container> 2>&1 | grep kill &
strace -p <pid-of-collector2-container> 2>&1 | grep kill &
strace -p <pid-of-collector3-container> 2>&1 | grep kill &

# Result: collector1 shows kill(666, SIGTERM) syscall

# Kill the strace processes, scale down collector1 on control plane
exit  # back to cks5632
k -n team-tulip scale deploy collector1 --replicas=0
```

**Key concepts:**
- `strace -p <pid>` attaches to a running process and prints all syscalls in real time.
- `kill(666, SIGTERM)` is the strace output format: `kill(target_pid, signal)`.
- Container PIDs are visible on the node — `crictl inspect` gives the host PID for a container's main process.
- Syscall tracing on production nodes is disruptive — use with care. In the exam, it's safe to run briefly.

---

## Question 15 | Apiserver TLS Settings

**Node:** `ssh cks7984`

Configure the API server to require TLS 1.3 as the minimum version. Then test that TLS 1.2 connections are rejected.

See: [`q15/apiserver-patch.yaml`](q15/apiserver-patch.yaml)

### Solution

```bash
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/15_kube-apiserver.yaml

vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Add to the command args:
#   - --tls-min-version=VersionTLS13

watch crictl ps  # wait for apiserver to restart

# Test that TLS 1.2 is now rejected
curl --tls-max 1.2 --tlsv1.2 https://127.0.0.1:6443 2>&1 > /opt/course/15/curl.log

cat /opt/course/15/curl.log
# curl: (35) OpenSSL SSL routines: tlsv1 alert protocol version
```

**Key concepts:**
- `--tls-min-version=VersionTLS13` forces the apiserver to reject any handshake below TLS 1.3.
- The valid values for `--tls-min-version` are: `VersionTLS10`, `VersionTLS11`, `VersionTLS12`, `VersionTLS13`.
- `curl --tls-max 1.2 --tlsv1.2` forces curl to use TLS 1.2 — the connection fails with a protocol error.
- The error `tlsv1 alert protocol version` confirms the server rejected the downgraded TLS version.
- Always backup the apiserver manifest before editing: if the manifest is broken, the apiserver won't restart.

---

## Question 16 | Docker Image Attack Surface

**Node:** `ssh cks5632`

Deployment `image-verify` in NS `team-clover` uses image `registry.local:5000/image-verify:v1`. Update the Dockerfile to reduce the attack surface, build as `:v2`, push, and update the Deployment.

See: [`q16/Dockerfile`](q16/Dockerfile), [`q16/run.sh`](q16/run.sh), [`q16/deployment.yaml`](q16/deployment.yaml)

### Solution

```bash
cd /opt/course/16/image

# Edit the Dockerfile (edit existing lines only — no new lines)
vim Dockerfile
# Changes:
#   FROM alpine:3.4        → FROM alpine:3.22
#   apk add vim curl nginx=1.10.3-r0  → apk add vim nginx>=1.18.0  (remove curl, update nginx)
#   USER root              → USER myuser

# Build as non-root user (podman, not docker — Kubernetes uses containerd)
podman build -t registry.local:5000/image-verify:v2 .

# Push
podman push registry.local:5000/image-verify:v2

# Update the Deployment
k -n team-clover set image deploy image-verify \
  image-verify=registry.local:5000/image-verify:v2

# Verify rollout
k -n team-clover rollout status deploy image-verify
k -n team-clover get pods
```

**Changes from v1 to v2:**

| Component | Before (v1) | After (v2) | Reason |
|-----------|-------------|------------|--------|
| Base image | `alpine:3.4` | `alpine:3.22` | Old alpine has many CVEs |
| `curl` | installed | removed | Reduces attack surface — not needed |
| `nginx` | `nginx=1.10.3-r0` | `nginx>=1.18.0` | Old version has known vulnerabilities |
| User | `root` | `myuser` | Never run containers as root |

**Key concepts:**
- Run containers as a non-root user — even if the container is compromised, the attacker has limited privileges.
- Removing unnecessary tools (`curl`) reduces the attack surface — fewer tools = fewer exploitation paths.
- Pin base image versions but allow minor updates for security patches (using `>=`).
- Use `podman` (rootless) instead of `docker` on the exam nodes — Docker may not be the container runtime used by Kubernetes.
- The task says "edit existing lines only — no new lines" — this means you cannot add a new `USER` line; the `USER root` line must be changed in place to `USER myuser`.

---

## Question 17 | Update Kubernetes

**Node:** `ssh cks9640` (controlplane), `ssh cks9640-node1` (worker)

Upgrade the cluster from 1.33.4 to 1.34.1 using `kubeadm`.

See: [`q17/upgrade-steps.sh`](q17/upgrade-steps.sh)

### Solution

**Controlplane (cks9640):**
```bash
# Drain the controlplane node
k drain cks9640 --ignore-daemonsets

# kubeadm is assumed to already be at 1.34.1 (or upgrade it first)
# apt-mark unhold kubeadm && apt install kubeadm=1.34.1-1.1 && apt-mark hold kubeadm

# Run the upgrade
kubeadm upgrade apply v1.34.1

# Upgrade kubelet and kubectl
apt-mark unhold kubelet kubectl
apt install kubelet=1.34.1-1.1 kubectl=1.34.1-1.1
apt-mark hold kubelet kubectl

# Restart kubelet
service kubelet restart

# Uncordon
k uncordon cks9640
```

**Worker (cks9640-node1):**
```bash
# Drain from controlplane
k drain cks9640-node1 --ignore-daemonsets

# SSH to worker
ssh cks9640-node1
sudo -i

# Upgrade kubeadm on the worker
apt-mark unhold kubeadm
apt install kubeadm=1.34.1-1.1
apt-mark hold kubeadm

# Run node upgrade (pulls kubelet config from the already-upgraded controlplane)
kubeadm upgrade node

# Upgrade kubelet and kubectl
apt-mark unhold kubelet kubectl
apt install kubelet=1.34.1-1.1 kubectl=1.34.1-1.1
apt-mark hold kubelet kubectl

# Restart kubelet
service kubelet restart

# Back on controlplane — uncordon
exit
k uncordon cks9640-node1

# Verify
k get nodes
# NAME              STATUS   ROLES           VERSION
# cks9640           Ready    control-plane   v1.34.1
# cks9640-node1     Ready    <none>          v1.34.1
```

**Key concepts:**
- `drain` evicts all non-DaemonSet Pods from the node before upgrade — use `--ignore-daemonsets` for DaemonSet Pods (they cannot be evicted).
- Controlplane is upgraded first with `kubeadm upgrade apply`. Workers use `kubeadm upgrade node` (which does not take the version argument — it reads from the controlplane's ConfigMap).
- `apt-mark hold`/`unhold` prevents apt from auto-upgrading Kubernetes components unexpectedly.
- The package version suffix `=1.34.1-1.1` is the Ubuntu/Debian package version — the `-1.1` is the package revision.
- Always `uncordon` after the upgrade — forgetting this leaves the node unschedulable.
