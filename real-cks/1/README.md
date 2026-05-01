# CKS Practice — Kubernetes 1.34

Each question is solved on a specific node via `ssh`. Use `sudo -i` to become root where needed.

---

## Question 1 | Contexts

**Node:** `ssh cks3477`

Write all context names into `/opt/course/1/contexts`, one per line. Extract the certificate of user `restricted@infra-prod` decoded to `/opt/course/1/cert`.

### Solution

```bash
k config get-contexts -o name > /opt/course/1/contexts

k config view --raw \
  -ojsonpath="{.users[?(.name == 'restricted@infra-prod')].user.client-certificate-data}" \
  | base64 -d > /opt/course/1/cert
```

---

## Question 2 | Image Vulnerability Scanning

**Node:** `ssh cks8930`

Scan these images with `trivy` for CVE-2020-10878 or CVE-2020-1967. Write images that have **neither** CVE into `/opt/course/2/good-images`.

- `nginx:1.16.1-alpine`
- `k8s.gcr.io/kube-apiserver:v1.18.0`
- `k8s.gcr.io/kube-controller-manager:v1.18.0`
- `docker.io/weaveworks/weave-kube:2.7.0`

### Solution

```bash
trivy image nginx:1.16.1-alpine | grep -E 'CVE-2020-10878|CVE-2020-1967'
trivy image k8s.gcr.io/kube-apiserver:v1.18.0 | grep -E 'CVE-2020-10878|CVE-2020-1967'
trivy image k8s.gcr.io/kube-controller-manager:v1.18.0 | grep -E 'CVE-2020-10878|CVE-2020-1967'
trivy image docker.io/weaveworks/weave-kube:2.7.0 | grep -E 'CVE-2020-10878|CVE-2020-1967'

# Only docker.io/weaveworks/weave-kube:2.7.0 has no CVEs
echo "docker.io/weaveworks/weave-kube:2.7.0" > /opt/course/2/good-images
```

---

## Question 3 | Apiserver Security

**Node:** `ssh cks8930`

The apiserver is accessible via a NodePort Service (`--kubernetes-service-node-port=31000`). Change it to ClusterIP only.

### Solution

```bash
sudo -i
# Remove the flag from the static Pod manifest
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Delete or comment out: --kubernetes-service-node-port=31000

watch crictl ps  # wait for apiserver to restart

# The kubernetes Service will still be NodePort — delete it, k8s recreates it as ClusterIP
k delete svc kubernetes
k get svc  # verify: TYPE=ClusterIP
```

---

## Question 4 | ServiceAccount Token Expiration

**Node:** `ssh cks5608`

Update `/opt/course/4/stream-multiplex.yaml`:
- Pod annotation `token-lifetime: "1200"`
- Use ServiceAccount `stream-multiplex`
- Disable automounting of SA tokens
- Mount SA token at `/var/run/secrets/custom/` with expiration 1200s

See: [`q4/stream-multiplex.yaml`](q4/stream-multiplex.yaml)

### Solution

```bash
cp /opt/course/4/stream-multiplex.yaml /opt/course/4/stream-multiplex.yaml_bak
# Apply the updated manifest (see q4/stream-multiplex.yaml)
k apply -f /opt/course/4/stream-multiplex.yaml
k -n team-coral get deploy
```

---

## Question 5 | CIS Benchmark

**Node:** `ssh cks7262` (controlplane), `ssh cks7262-node1` (worker)

Fix CIS Benchmark findings:

**Controlplane:**
- `1.3.2` — set `--profiling=false` on kube-controller-manager
- `1.1.12` — set ownership of `/var/lib/etcd` to `etcd:etcd`

**Worker:**
- `4.1.9` — set permissions of `/var/lib/kubelet/config.yaml` to `600`
- `4.2.3` — verify `clientCAFile` is set in kubelet config (already passing)

### Solution

```bash
# Controlplane
sudo -i
kube-bench run --targets=master --check=1.3.2
vim /etc/kubernetes/manifests/kube-controller-manager.yaml
# Add: - --profiling=false

chown etcd:etcd /var/lib/etcd

# Worker
ssh cks7262-node1
sudo -i
chmod 600 /var/lib/kubelet/config.yaml
```

---

## Question 6 | Immutable Root FileSystem

**Node:** `ssh cks2546`

Deployment `immutable-deployment` in namespace `team-purple` must have a read-only root filesystem. Only `/tmp` should be writable.

See: [`q6/immutable-deployment.yaml`](q6/immutable-deployment.yaml)

### Solution

```bash
cp /opt/course/6/immutable-deployment.yaml /opt/course/6/immutable-deployment-new.yaml
# Edit to add readOnlyRootFilesystem: true and emptyDir for /tmp
k delete -f /opt/course/6/immutable-deployment-new.yaml
k create -f /opt/course/6/immutable-deployment-new.yaml

# Verify
k -n team-purple exec <pod> -- touch /abc.txt   # must fail
k -n team-purple exec <pod> -- touch /tmp/abc.txt  # must succeed
```

---

## Question 7 | Pod Security Standard and Admission

**Node:** `ssh cks5608`

Configure namespace `team-sepia`:
- PSA mode `audit` for level `baseline`
- PSA mode `warn` for level `restricted`

Then create the Pod from `/opt/course/7/bad-pod.yaml` and save warnings to `/opt/course/7/bad-pod.log`.

See: [`q7/namespace-pss.yaml`](q7/namespace-pss.yaml), [`q7/bad-pod.yaml`](q7/bad-pod.yaml)

### Solution

```bash
k label ns team-sepia pod-security.kubernetes.io/audit=baseline
k label ns team-sepia pod-security.kubernetes.io/warn=restricted

kubectl -f /opt/course/7/bad-pod.yaml apply 2>&1 | tee /opt/course/7/bad-pod.log
```

PSA levels:
- `privileged` — unrestricted
- `baseline` — minimally restrictive
- `restricted` — heavily restricted

Modes:
- `enforce` — reject violating Pods
- `audit` — allow but log to audit
- `warn` — allow but show user-facing warning

---

## Question 8 | Docker Configuration and Usage

**Node:** `ssh cks4024` (Docker, not used by k8s)

Disable inter-container communication (ICC) in Docker. Create `container1` and `container2` (image `nginx:1-alpine`, `--restart always`, background).

### Solution

```bash
sudo -i
vim /etc/docker/daemon.json
# Add: "icc": false

service docker restart

docker run -d --name container1 --restart always nginx:1-alpine
docker run -d --name container2 --restart always nginx:1-alpine

# Verify containers cannot ping each other
docker inspect container1 | grep IPAddress
docker exec container2 ping <container1-ip>  # must fail (no response)
```

---

## Question 9 | AppArmor Profile

**Node:** `ssh cks7262`

Install AppArmor profile from `/opt/course/9/profile` on node `cks7262-node1`. Label the node `security=apparmor`. Create Deployment `apparmor` in `default` namespace using the profile on container `c1`.

See: [`q9/apparmor-profile`](q9/apparmor-profile), [`q9/apparmor-deploy.yaml`](q9/apparmor-deploy.yaml)

### Solution

```bash
# Copy and install profile on worker
scp /opt/course/9/profile cks7262-node1:~/
ssh cks7262-node1
sudo apparmor_parser -q ./profile
sudo apparmor_status | grep very-secure

# Back on controlplane
k label node cks7262-node1 security=apparmor
k -f q9/apparmor-deploy.yaml create

# Pod will CrashLoopBackOff (profile denies writes, nginx needs them)
k logs apparmor-<pod> > /opt/course/9/logs
```

---

## Question 10 | Container Runtime Sandbox gVisor

**Node:** `ssh cks7262`

Create RuntimeClass `gvisor` with handler `runsc`. Create Pod `gvisor-test` in `team-purple` on node `cks7262-node1`. Write `dmesg` output to `/opt/course/10/gvisor-test-dmesg`.

See: [`q10/runtimeclass.yaml`](q10/runtimeclass.yaml), [`q10/gvisor-pod.yaml`](q10/gvisor-pod.yaml)

### Solution

```bash
k -f q10/runtimeclass.yaml create
k -f q10/gvisor-pod.yaml create

k -n team-purple get pod gvisor-test
k -n team-purple exec gvisor-test -- dmesg
# Output should start with: "[    0.000000] Starting gVisor..."

k -n team-purple exec gvisor-test -- dmesg > /opt/course/10/gvisor-test-dmesg
```

---

## Question 11 | Secret Management

**Node:** `ssh cks2546`

**Step 1:** Update password of immutable Secret `db-con` in `team-khaki-us-east-ad1` to `4c!29f_Ee2e`. Restart affected Pods.

**Step 2:** Move Secret `user-data` from `team-khaki-us-east-ad1` to `team-khaki-us-east-ad2`.

**Step 3:** Convert ConfigMap `app-data` in `team-khaki-us-east-ad1` to a Secret. Update Pods using it. Delete the ConfigMap.

### Solution

```bash
# Step 1 — immutable Secret must be deleted and recreated
k -n team-khaki-us-east-ad1 get secret db-con -oyaml > 11_db-con.yaml
# Edit: password: $(echo -n '4c!29f_Ee2e' | base64)
k delete -f 11_db-con.yaml
k apply -f 11_db-con.yaml
# Restart Pods using the Secret
k -n team-khaki-us-east-ad1 scale deploy app-green-sky --replicas 0
k -n team-khaki-us-east-ad1 scale deploy app-green-sky --replicas 2

# Step 2 — move Secret
k -n team-khaki-us-east-ad1 get secret user-data -oyaml > 11_user-data.yaml
# Edit namespace to team-khaki-us-east-ad2
k apply -f 11_user-data.yaml
k -n team-khaki-us-east-ad1 delete secret user-data

# Step 3 — convert ConfigMap to Secret
k -n team-khaki-us-east-ad1 get cm app-data -oyaml > 11_app-data.yaml
# Change kind: ConfigMap -> kind: Secret, data -> stringData
# Remove resourceVersion, uid, creationTimestamp, annotations
k apply -f 11_app-data.yaml
# Update Deployments to use secretName: app-data instead of configMapKeyRef
k -n team-khaki-us-east-ad1 delete cm app-data
```

**Note:** `list` verb on Secrets allows reading content via `-oyaml`. Always audit RBAC for Secrets carefully.

---

## Question 12 | ImagePolicyWebhook

**Node:** `ssh cks4024`

Enable the `ImagePolicyWebhook` admission plugin on the apiserver. Use the existing webhook backend in `team-white`. Mount `/opt/course/12/webhook` as `/etc/kubernetes/webhook` in the apiserver.

See: [`q12/admission-config.yaml`](q12/admission-config.yaml)

### Solution

```bash
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/s12_kube-apiserver.yaml

# Create AdmissionConfiguration
cp q12/admission-config.yaml /opt/course/12/webhook/admission-config.yaml

vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Add flags:
#   - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
#   - --admission-control-config-file=/etc/kubernetes/webhook/admission-config.yaml
# Add volumeMount: /etc/kubernetes/webhook (readOnly)
# Add hostPath volume: /opt/course/12/webhook -> /etc/kubernetes/webhook

watch crictl ps  # wait for restart

# Test
k run test1 --image=something/danger-danger  # must be FORBIDDEN
k run test2 --image=nginx:alpine             # must succeed
```

**Note:** `defaultAllow: true` means if the webhook is unreachable, Pods are allowed. Setting it to `false` means all Pods are blocked if the backend is down — dangerous for cluster-critical components.

---

## Question 13 | CiliumNetworkPolicy Metadata Server

**Node:** `ssh cks8930`

Block access to metadata server at `192.168.100.21:9055` from namespace `metadata-access`. Allow all other egress (internet, same namespace, kube-system).

See: [`q13/cilium-network-policy.yaml`](q13/cilium-network-policy.yaml)

### Solution

```bash
k apply -f q13/cilium-network-policy.yaml

# Verify deny
k exec -it -n metadata-access pod1 -- curl http://192.168.100.21:9055  # must time out

# Verify allow
k exec -it -n metadata-access pod1 -- nslookup kubernetes.default.svc.cluster.local  # DNS works
k exec -it -n metadata-access pod1 -- curl google.com                                  # internet works
k exec -it -n metadata-access pod1 -- curl <pod2-ip>                                   # same-ns works
```

**Key rules:**
- Multiple entries under `egress:` are OR'd
- Multiple selectors within one entry are AND'd
- `egressDeny` takes precedence over `egress` allow rules
- `0.0.0.0/0` covers external IPs only; Cilium uses identity-based model for cluster-internal endpoints

---

## Question 14 | ETCD Secret Encryption

**Node:** `ssh cks7262`

An `EncryptionConfiguration` exists at `/etc/kubernetes/etcd/ec.yaml`. Decode its password, configure the apiserver to use it, then re-encrypt all Secrets in `team-magenta`.

See: [`q14/encryption-config.yaml`](q14/encryption-config.yaml)

### Solution

```bash
sudo -i

# Step 1 — decode the password
echo d0hhVGFTZUN1UmVQYVNzIQ== | base64 -d > /opt/course/14/password.txt

# Step 2+3 — update apiserver manifest
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/14_kube-apiserver.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Add flag:   - --encryption-provider-config=/etc/kubernetes/etcd/ec.yaml
# Add volumeMount: /etc/kubernetes/etcd (readOnly)
# Add hostPath volume: /etc/kubernetes/etcd -> /etc/kubernetes/etcd

watch crictl ps  # wait for restart

# Step 4 — re-encrypt existing Secrets (recreate them so apiserver re-writes them)
k -n team-magenta get secrets -o json | kubectl replace -f -

# Optional: verify encryption in etcd
ETCDCTL_API=3 etcdctl \
  --cert /etc/kubernetes/pki/apiserver-etcd-client.crt \
  --key /etc/kubernetes/pki/apiserver-etcd-client.key \
  --cacert /etc/kubernetes/pki/etcd/ca.crt \
  get /registry/secrets/team-magenta/proxy-01
# Output should start with: k8s:enc:aesgcm:...
```

---

## Question 15 | Configure TLS on Ingress

**Node:** `ssh cks2546`

Replace the default self-signed certificate on Ingress `secure` in `team-pink` with the provided certificate at `/opt/course/15/tls.key` and `/opt/course/15/tls.crt`.

### Solution

```bash
k -n team-pink create secret tls tls-secret \
  --key /opt/course/15/tls.key \
  --cert /opt/course/15/tls.crt

k -n team-pink edit ing secure
# Add under spec:
#   tls:
#     - hosts:
#       - secure-ingress.test
#       secretName: tls-secret

# Verify
curl -kv https://secure-ingress.test:31443/api
# subject: CN=secure-ingress.test — confirms our cert is used
```

---

## Question 16 | Runtime Security with Falco

**Node:** `ssh cks5608`

Add two rules to `/etc/falco/falco_rules.local.yaml`. Run Falco for 30+ seconds. Save output to `/opt/course/16/logs`.

See: [`q16/falco-rules.yaml`](q16/falco-rules.yaml)

### Solution

```bash
sudo -i
vim /etc/falco/falco_rules.local.yaml
# Add rules from q16/falco-rules.yaml

falco > /opt/course/16/logs
# Wait 30+ seconds, then Ctrl+C

grep custom_rule_1 /opt/course/16/logs | wc -l
grep custom_rule_2 /opt/course/16/logs | wc -l
```

**Rule 1** — files accessed under `/etc/kubernetes` from containers:
```yaml
condition: container and evt.type in (open, openat) and fd.name startswith /etc/kubernetes
output: custom_rule_1 file=%fd.name container=%container.id
priority: WARNING
```

**Rule 2** — kill syscalls:
```yaml
condition: syscall.type = kill
output: custom_rule_2 event_signal=%evt.arg.sig event_pid=%evt.arg.pid container=%container.id
priority: INFO
```

`fd.name` = full path; `fd.filename` = basename only; `fd.directory` = directory part.

---

## Question 17 | Audit Log Policy

**Node:** `ssh cks3477`

Update apiserver to keep only 1 backup of audit logs (`--audit-log-maxbackup=1`). Update the audit policy to log:
- Secrets at `Metadata` level
- `system:nodes` group at `RequestResponse` level
- Everything else: `None`

Clear the log file after applying.

See: [`q17/audit-policy.yaml`](q17/audit-policy.yaml)

### Solution

```bash
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/17_kube-apiserver.yaml

vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Change: --audit-log-maxbackup=1

vim /etc/kubernetes/audit/policy.yaml
# Replace with contents of q17/audit-policy.yaml

# Restart apiserver cleanly
cd /etc/kubernetes/manifests
mv kube-apiserver.yaml ..
watch crictl ps  # wait until gone
echo > /etc/kubernetes/audit/logs/audit.log
mv ../kube-apiserver.yaml .
watch crictl ps  # wait until running

# Verify
cat /etc/kubernetes/audit/logs/audit.log | tail | yq -p json -o json
```

---

## Preview Question 1 | RBAC

**Node:** `ssh cks3477`

User `gianna` has `list` on Secrets cluster-wide — this allows reading content via `-oyaml`. Remove `secrets` from the ClusterRole. Create RBAC to allow `gianna` to create Pods and Deployments in namespaces `security`, `restricted`, `internal`.

### Solution

```bash
# Check
k auth can-i list secrets --as gianna  # yes — but list allows -oyaml content exposure!

# Fix: remove secrets from ClusterRole gianna
k edit clusterrole gianna
# Remove: - secrets

# Create Role for pod/deployment creation
k create role pod-deploy-creator \
  --verb=create \
  --resource=pods,deployments \
  -n security

# Bind in each namespace (or use a single ClusterRole + RoleBindings)
for ns in security restricted internal; do
  k create rolebinding gianna-creator \
    --role=pod-deploy-creator \
    --user=gianna \
    -n $ns
done
```

**Note:** `list` verb on Secrets allows reading Secret data via `kubectl get secrets -oyaml`. This is a common misconfiguration — `get` is required for individual access, but `list` enables bulk data exposure.
