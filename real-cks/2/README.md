# CKS Practice Set 2

17 practical CKS questions covering a broad range of Kubernetes security topics.

## Questions

| # | Topic | Key Tools/Concepts |
|---|-------|--------------------|
| 1 | SBOM generation and vulnerability scanning | bom, trivy, SPDX, CycloneDX |
| 2 | Runtime security with Falco | Custom rules, log format, journalctl |
| 3 | Manual static security analysis | Dockerfiles, YAML manifests, credential exposure |
| 4 | Pod Security Standard | PSS baseline, Namespace labels, admission |
| 5 | NetworkPolicy | Egress restriction between namespaces |
| 6 | Verify platform binaries | sha512sum, binary integrity |
| 7 | KubeletConfiguration | kubeadm, containerLogMaxSize/Files |
| 8 | CiliumNetworkPolicy | L3/L4 deny, mutual authentication |
| 9 | Certificates and CSR | approve/deny, openssl, base64 |
| 10 | Istio sidecar injection | istio-injection label, rollout restart |
| 11 | Secrets in ETCD | etcdctl, direct read, base64 decode |
| 12 | Hack Secrets (RBAC escape) | restricted context, exec into pods, SA tokens |
| 13 | RBAC Operator | Role, ClusterRole, CSR approval permissions |
| 14 | Syscall Activity | crictl, strace, kill syscall detection |
| 15 | Apiserver TLS settings | --tls-min-version, VersionTLS13, curl test |
| 16 | Docker image attack surface | alpine, curl removal, USER, podman build/push |
| 17 | Kubernetes cluster upgrade | kubeadm upgrade, apt, drain/uncordon |

## Directory Structure

Each question has its own directory with:
- `README.md` — step-by-step setup and verification
- YAML manifests ready to apply (where applicable)
- Config snippets and patches

```
q1/   — SBOM (commands only)
q2/   — falco-custom.yaml
q3/   — static analysis guide
q4/   — namespace-patch.yaml
q5/   — networkpolicy-gateway-v1.yaml, networkpolicy-gateway-v2.yaml
q6/   — binary verification (commands only)
q7/   — kubelet-config-patch.yaml
q8/   — p1.yaml, p2.yaml, p3.yaml (CiliumNetworkPolicy)
q9/   — new-csr-template.yaml
q10/  — namespace-patch.yaml (Istio injection)
q11/  — etcd secret reading (commands only)
q12/  — RBAC escape investigation guide
q13/  — rbac.yaml
q14/  — syscall investigation guide
q15/  — apiserver-patch.yaml
q16/  — Dockerfile (reference)
q17/  — upgrade guide
```

## Cluster Assumptions

- Multi-node cluster (1 controlplane + workers)
- Cilium as CNI (Q5, Q8)
- Falco deployed on worker nodes (Q2)
- Istio installed in istio-system (Q10)
- ETCD accessible via `/etc/kubernetes/pki` certs (Q11)
