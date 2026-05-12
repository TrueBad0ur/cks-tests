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

The content of `/opt/course/1/contexts` should look like:
```
gianna@infra-prod
kubernetes-admin@kubernetes
restricted@infra-prod
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

Results:
- `nginx:1.16.1-alpine` — has CVE-2020-1967
- `k8s.gcr.io/kube-apiserver:v1.18.0` — has CVE-2020-10878
- `k8s.gcr.io/kube-controller-manager:v1.18.0` — has CVE-2020-10878
- `docker.io/weaveworks/weave-kube:2.7.0` — **no CVEs** (the answer)

---

## Question 3 | Apiserver Security

**Node:** `ssh cks8930`

The apiserver is accessible via a NodePort Service (`--kubernetes-service-node-port=31000`). Change it to ClusterIP only.

### Solution

```bash
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/3_kube-apiserver.yaml

vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Remove or comment out: --kubernetes-service-node-port=31000

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
vim /opt/course/4/stream-multiplex.yaml
# Apply the updated manifest (see q4/stream-multiplex.yaml)
k apply -f /opt/course/4/stream-multiplex.yaml
k -n team-coral get deploy
k -n team-coral get pod
```

Key points:
- `automountServiceAccountToken: false` disables the default auto-mount
- The projected volume with `serviceAccountToken` source allows a custom expiry and mount path
- The annotation `token-lifetime: "1200"` must be a string value (quoted)
- **CRITICAL:** The annotation must be under `spec.template.metadata.annotations` (Pod template), NOT under `metadata.annotations` (Deployment). Deployment-level annotations are metadata about the Deployment object itself — they don't appear on Pods. The scoring checks `deployment.spec.template.metadata.annotations`.

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
ssh cks7262
sudo -i
kube-bench run --targets=master --check=1.3.2

vim /etc/kubernetes/manifests/kube-controller-manager.yaml
# Add: - --profiling=false

kube-bench run --targets=master --check=1.1.12
chown etcd:etcd /var/lib/etcd

# Worker
ssh cks7262-node1
sudo -i
kube-bench run --targets=node --check=4.1.9
chmod 600 /var/lib/kubelet/config.yaml

kube-bench run --targets=node --check=4.2.3
# Should already be passing — clientCAFile is set in /var/lib/kubelet/config.yaml
```

---

## Question 6 | Immutable Root FileSystem

**Node:** `ssh cks2546`

Deployment `immutable-deployment` in namespace `team-purple` must have a read-only root filesystem. Only `/tmp` should be writable. Do not modify the Docker image.

Save the updated YAML under `/opt/course/6/immutable-deployment-new.yaml` and update the running Deployment.

See: [`q6/immutable-deployment.yaml`](q6/immutable-deployment.yaml)

### Solution

```bash
cp /opt/course/6/immutable-deployment.yaml /opt/course/6/immutable-deployment-new.yaml
vim /opt/course/6/immutable-deployment-new.yaml
# Add readOnlyRootFilesystem: true to container securityContext
# Add emptyDir volume for /tmp

k delete -f /opt/course/6/immutable-deployment-new.yaml
k create -f /opt/course/6/immutable-deployment-new.yaml

# Verify
k -n team-purple exec <pod> -- touch /abc.txt   # must fail (Read-only file system)
k -n team-purple exec <pod> -- touch /tmp/abc.txt  # must succeed
```

Key changes to the Deployment:
```yaml
containers:
- name: busybox
  securityContext:
    readOnlyRootFilesystem: true
  volumeMounts:
  - mountPath: /tmp
    name: temp-vol
volumes:
- name: temp-vol
  emptyDir: {}
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
# Or:
kubectl -f /opt/course/7/bad-pod.yaml apply 2> /opt/course/7/bad-pod.log
```

The bad-pod has `allowPrivilegeEscalation: true` which violates `restricted` level — warning is shown but Pod is still created because mode is `warn` (not `enforce`).

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

Example `daemon.json`:
```json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "storage-driver": "overlay2",
  "registry-mirrors": ["https://mirror.gcr.io"],
  "mtu": 1454,
  "icc": false
}
```

**Note:** Docker is running on `cks4024` but is NOT used by Kubernetes (kubelet uses containerd). This question is Docker-only.

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
exit

# Label node
k label node cks7262-node1 security=apparmor

# Create deployment
k -f q9/apparmor-deploy.yaml create

# Pod will CrashLoopBackOff (profile denies all writes, nginx needs them)
k logs apparmor-<pod> > /opt/course/9/logs
```

The profile `very-secure` denies all file writes (`deny /** w`). Nginx cannot start because it needs to write to `/dev/null` and `/var/cache/nginx/`.

The AppArmor profile is specified via `securityContext.appArmorProfile` (K8s 1.30+):
```yaml
securityContext:
  appArmorProfile:
    type: Localhost
    localhostProfile: very-secure
```

**Local cluster:** These nodes do not have AppArmor kernel support (`/sys/kernel/security/apparmor` absent). The configs are correct and would work on Ubuntu nodes (real exam). Use `q9/apparmor-loader.yaml` to load the profile on AppArmor-capable nodes before applying `q9/apparmor-deploy.yaml`.

**CRITICAL — container-level vs pod-level:** The task says "only for this container". The `appArmorProfile` can be set at `spec.securityContext` (pod level, applies to all containers) OR at `spec.containers[].securityContext` (container level, applies only to that container). The scoring checks for container-level. Always put it inside the container definition:
```yaml
containers:
- name: c1
  securityContext:         # ← container level
    appArmorProfile:
      type: Localhost
      localhostProfile: very-secure
```
NOT at `spec.securityContext` (pod level).

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

k -n team-purple exec gvisor-test > /opt/course/10/gvisor-test-dmesg -- dmesg
```

**Note:** `nodeName: worker1` (updated from exam's `cks7262-node1`). gVisor must be installed on that node (`runsc` handler). Without it, pod stays in `ContainerCreating` with error `no runtime for "runsc" is configured`. The real CKS exam nodes have gVisor pre-installed.

**Local cluster:** RuntimeClass `gvisor` is applied but the pod cannot run — these nodes don't have `runsc`. To verify the RuntimeClass exists: `kubectl get runtimeclass gvisor`.

---

## Question 11 | Secret Management

**Node:** `ssh cks2546`

**Step 1:** Update password of immutable Secret `db-con` in `team-khaki-us-east-ad1` to `4c!29f_Ee2e`. Restart affected Pods.

**Step 2:** Move Secret `user-data` from `team-khaki-us-east-ad1` to `team-khaki-us-east-ad2`.

**Step 3:** Convert ConfigMap `app-data` in `team-khaki-us-east-ad1` to a Secret. Update Pods using it. Delete the ConfigMap.

### Solution

```bash
# Step 1 — immutable Secret must be deleted and recreated
# ORDERING IS CRITICAL: delete old → create new → THEN restart pods.
# If you restart pods before recreating the secret, they restart with the old value.
k -n team-khaki-us-east-ad1 get secret db-con -oyaml > 11_db-con.yaml
# Edit the password value (base64 encoded): echo -n '4c!29f_Ee2e' | base64
k -n team-khaki-us-east-ad1 delete secret db-con
k apply -f 11_db-con.yaml   # immutable: true must stay in the file
# Only now restart pods so they pick up the new secret value
k -n team-khaki-us-east-ad1 rollout restart deploy app-green-sky

# Step 2 — move Secret
k -n team-khaki-us-east-ad1 get secret user-data -oyaml > 11_user-data.yaml
# Edit namespace to team-khaki-us-east-ad2, remove resourceVersion/uid/creationTimestamp
k apply -f 11_user-data.yaml
k -n team-khaki-us-east-ad1 delete secret user-data

# Step 3 — convert ConfigMap to Secret (see q11/app-data-secret.yaml)
k -n team-khaki-us-east-ad1 get cm app-data -oyaml > 11_app-data.yaml
# Changes to make:
#   kind: ConfigMap  →  kind: Secret
#   data:            →  stringData:  (values stay plain text, no base64 needed)
#   add: immutable: true
#   remove: resourceVersion, uid, creationTimestamp, annotations
k apply -f 11_app-data.yaml

# Update Deployment: volume type changes from configMap to secret
k -n team-khaki-us-east-ad1 edit deploy app-purple-sunrise
# volumes section: change from:
#   - configMap:
#       defaultMode: 420
#       name: app-data
#     name: app-config
# to:
#   - secret:
#       defaultMode: 420
#       secretName: app-data
#     name: app-config

k -n team-khaki-us-east-ad1 delete cm app-data
```

**Notes:**
- Immutable Secrets cannot be edited — they must be deleted and recreated. The `immutable: true` field must be kept in the recreated Secret.
- For env vars (`valueFrom.secretKeyRef`), pods must be restarted to pick up new secret values. For volume mounts, Kubernetes updates them automatically (within ~1 min) — but env vars are frozen at pod start.
- `list` verb on Secrets allows reading content via `-oyaml` (not just `get`). Always audit RBAC for Secrets carefully.

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
vim /opt/course/12/webhook/admission-config.yaml
# (see q12/admission-config.yaml)

vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Change: --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook
# Add:    --admission-control-config-file=/etc/kubernetes/webhook/admission-config.yaml
# Add volumeMount: mountPath: /etc/kubernetes/webhook, name: webhook, readOnly: true
# Add volume: hostPath: path: /opt/course/12/webhook, type: DirectoryOrCreate, name: webhook

watch crictl ps  # wait for restart

# Test
k run test1 --image=something/danger-danger  # must be FORBIDDEN
k run test2 --image=nginx:alpine             # must succeed
```

**Note:** `defaultAllow: true` means if the webhook is unreachable, Pods are allowed. Setting it to `false` blocks all Pods when the backend is down — dangerous for cluster-critical components.

**CRITICAL — two-layer structure:** The `admission-config.yaml` file is NOT just the `imagePolicy:` block. It must be a full `AdmissionConfiguration` Kubernetes object that wraps the plugin config:
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration       # ← outer wrapper
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:                    # ← inner plugin config
      kubeConfigFile: /etc/kubernetes/webhook/webhook.yaml
      ...
```
The `imagePolicy:` section alone (without the wrapper) is not a valid file for `--admission-control-config-file`.

---

## Question 13 | CiliumNetworkPolicy Metadata Server

**Node:** `ssh cks8930`

Block access to metadata server at `192.168.100.21:9055` from namespace `metadata-access`. Allow all other egress (internet, same namespace, kube-system).

See: [`q13/cilium-network-policy.yaml`](q13/cilium-network-policy.yaml)

### Solution

```bash
k apply -f q13/cilium-network-policy.yaml

# Verify deny
k exec -it -n metadata-access pod1-7c7bdb75cb-sv5rb -- curl http://192.168.100.21:9055  # must time out

# Verify allow
k exec -it -n metadata-access pod1-7c7bdb75cb-sv5rb -- nslookup kubernetes.default.svc.cluster.local  # DNS works
k exec -it -n metadata-access pod1-7c7bdb75cb-sv5rb -- curl google.com                                  # internet works
k exec -it -n metadata-access pod1-7c7bdb75cb-sv5rb -- curl <pod2-ip>                                   # same-ns works
```

**Key rules:**
- Multiple entries under `egress:` are OR'd
- Multiple selectors within one entry are AND'd
- `egressDeny` takes precedence over `egress` allow rules — even if `0.0.0.0/0` would otherwise allow an IP, `egressDeny` overrides it
- `0.0.0.0/0` in Cilium covers **external IPs only**. Cluster-internal traffic (pods, services) is identity-based — you must use `toEndpoints`, not `toCIDR`, to allow it
- `toEndpoints` in a namespaced policy is NOT automatically scoped to that namespace (unlike native NetworkPolicy). You must explicitly use `k8s:io.kubernetes.pod.namespace: <ns>` label to restrict to a namespace
- `192.168.100.21` is a node IP (external to the pod network) → falls under CIDR rules, not endpoint rules. That's why `0.0.0.0/0` allows it and `egressDeny` is needed to block it

---

## Question 14 | ETCD Secret Encryption

**Node:** `ssh cks7262`

An `EncryptionConfiguration` exists at `/etc/kubernetes/etcd/ec.yaml`. Decode its password, configure the apiserver to use it, then re-encrypt all Secrets in `team-magenta`.

### Solution

```bash
sudo -i

# Step 1 — decode the password
echo d0hhVGFTZUN1UmVQYVNzIQ== | base64 -d > /opt/course/14/password.txt
# Result: wHaTaSeCuRePaSs!

# Step 2+3 — update apiserver manifest
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/14_kube-apiserver.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Add flag:   - --encryption-provider-config=/etc/kubernetes/etcd/ec.yaml
# Add volumeMount: mountPath: /etc/kubernetes/etcd, name: etcd, readOnly: true
# Add volume: hostPath: path: /etc/kubernetes/etcd, type: DirectoryOrCreate, name: etcd

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

The EncryptionConfiguration at `/etc/kubernetes/etcd/ec.yaml`:
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aesgcm:
          keys:
            - name: key1
              secret: d0hhVGFTZUN1UmVQYVNzIQ==
      - identity: {}  # needed so existing unencrypted secrets can still be read
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
condition: evt.type = kill
output: custom_rule_2 event_signal=%evt.arg.sig event_pid=%evt.arg.pid container=%container.id
priority: INFO
```

**Key Falco field names to know:**
- `fd.name` = full file path (what the task calls `{{FILEPATH}}`)
- `container.id` = container ID (what the task calls `{{CONTAINER_ID}}`)
- `container` = built-in macro: true if the process is inside a container
- `evt.type` = event type (`open`, `openat` for file reads; `kill` for kill syscall)
- `evt.arg.sig`, `evt.arg.pid` = arguments of the event (given in task output format)

`fd.name` = full path; `fd.filename` = basename only; `fd.directory` = directory part.

**How Falco loads rules:** `/etc/falco/falco.yaml` lists rules files including `/etc/falco/falco_rules.local.yaml`. Falco reads this file automatically on startup — no extra configuration needed. Just add rules there and run `falco`.

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

**Key audit policy notes:**
- Field for groups is `userGroups` (audit policy API) — NOT `groups` (RBAC API) and NOT `users`
- **Rule order matters** — first matching rule wins. Secrets rule must come BEFORE system:nodes rule, because kubelets (system:nodes) read Secrets. If system:nodes rule is first, kubelet Secret reads log at RequestResponse — breaking "Secret entries only at Metadata"
- After policy change, clear **all** log files including rotated backups (`audit.log.*`) — scoring reads the entire logs directory

```bash
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/17_kube-apiserver.yaml

vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Change: --audit-log-maxbackup=1

vim /etc/kubernetes/audit/policy.yaml
# Replace with contents of q17/audit-policy.yaml

# Restart apiserver cleanly and clear logs
cd /etc/kubernetes/manifests
mv kube-apiserver.yaml ..
watch crictl ps           # wait until apiserver container disappears

# Clear ALL log files — scoring reads the whole directory including rotated backups
echo > /etc/kubernetes/audit/logs/audit.log
rm -f /etc/kubernetes/audit/logs/audit.log.*   # delete rotated backup files

mv ../kube-apiserver.yaml .
watch crictl ps           # wait until running again

# Verify new entries match the policy
cat /etc/kubernetes/audit/logs/audit.log | python3 -c "
import sys, json
for line in sys.stdin:
    e = json.loads(line.strip())
    print(e['level'], e.get('user',{}).get('username',''), e.get('objectRef',{}).get('resource',''))
" | head -20
```

---

## Preview Question 1 | RBAC

**Node:** `ssh cks3477`

User `gianna` has `list` on Secrets cluster-wide — this allows reading content via `-oyaml`. Remove `secrets` from the ClusterRole. Create RBAC to allow `gianna` to create Pods and Deployments in namespaces `security`, `restricted`, `internal`.

### Solution

```bash
# Check — list allows bulk content exposure via -oyaml!
k auth can-i list secrets --as gianna  # yes
k config use-context gianna@infra-prod
k -n security get secrets -oyaml | grep password  # reveals secret data!

# Fix: remove secrets from ClusterRole gianna
k config use-context kubernetes-admin@kubernetes
k edit clusterrole gianna
# Remove: - secrets from the resources list

# Create ClusterRole for pod/deployment creation (reusable across namespaces)
k create clusterrole gianna-additional \
  --verb=create \
  --resource=pods \
  --resource=deployments

# Bind in each namespace via RoleBinding (ClusterRole + RoleBinding pattern)
for ns in security restricted internal; do
  k -n $ns create rolebinding gianna-additional \
    --clusterrole=gianna-additional \
    --user=gianna
done
```

**Note:** `list` verb on Secrets enables reading all Secret data via `kubectl get secrets -oyaml`. Use ClusterRole + RoleBinding (not ClusterRoleBinding) so the permission applies only in specific namespaces.

---

## Preview Question 2 | Secrets RBAC Investigation

**Node:** `ssh cks3477`

ServiceAccount `p.auster` had too broad access. Find which Secrets in namespace `security` it accessed via audit logs at `/opt/course/p2/audit.log`. Change the password of accessed Secrets.

### Solution

```bash
# Filter audit log for p.auster Secret access
cat /opt/course/p2/audit.log | grep "p.auster" | grep Secret | grep get | jq

# Results show vault-token and mysql-admin were accessed
echo -n new-vault-pass | base64
k -n security edit secret vault-token
# Update the password field

echo -n new-mysql-pass | base64
k -n security edit secret mysql-admin
# Update the password field
```

The audit log revealed that `system:serviceaccount:security:p.auster` performed `get` on:
- `/api/v1/namespaces/security/secrets/vault-token`
- `/api/v1/namespaces/security/secrets/mysql-admin`

**Note:** Audit logs at `RequestResponse` level contain full Secret content — another reason to only log at `Metadata` level for Secrets.

---

## Preview Question 3 | Unknown Miner Process

**Node:** `ssh cks8930`

A security scan reports an unknown miner process listening on port 6666 on one of the nodes. Kill the process and delete the binary.

### Solution

```bash
sudo -i

# Check controlplane first
ss -plnt | grep 6666
# Not found on controlplane

# Check worker node
ssh cks8930-node1
ss -plnt | grep 6666
# LISTEN   *:6666   *:*   users:(("system-atm",pid=9321,fd=3))

# Find binary path via /proc
ls -lh /proc/9321/exe
# -> /usr/bin/system-atm

# Kill and delete
kill -9 9321
rm /usr/bin/system-atm

# Verify
ss -plnt | grep 6666
```
