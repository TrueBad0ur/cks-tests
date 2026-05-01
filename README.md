# cks-labs

Practice materials for the Certified Kubernetes Security Specialist (CKS) exam.

## Structure

```
cks-labs/
├── real-cks/1/       # CKS practice set 1 — 17 questions with configs and test pods
├── prepare/          # Task-based labs (Falco, ETCD, audit, RBAC, etc.)
├── auth/             # Kubernetes auth deep-dive (X.509 users, ServiceAccounts)
├── certificates/     # Certificate management labs
├── kodekloud/        # KodeKloud CKS exercises
└── tetragon/         # Tetragon runtime security
```

## real-cks/1

17 practical CKS questions covering:

| # | Topic |
|---|---|
| 1 | Contexts & certificate extraction |
| 2 | Image vulnerability scanning (trivy) |
| 3 | Apiserver security (NodePort → ClusterIP) |
| 4 | ServiceAccount token expiration & projected volumes |
| 5 | CIS Benchmark (kube-bench) |
| 6 | Immutable root filesystem |
| 7 | Pod Security Standards & Admission |
| 8 | Docker ICC |
| 9 | AppArmor profiles |
| 10 | gVisor RuntimeClass |
| 11 | Secret management (immutable, move, convert from ConfigMap) |
| 12 | ImagePolicyWebhook |
| 13 | CiliumNetworkPolicy (block metadata server) |
| 14 | ETCD encryption at rest |
| 15 | TLS on Ingress |
| 16 | Falco custom rules |
| 17 | Audit log policy |

Each question has its own directory (`q1/`–`q17/`) with:
- YAML manifests ready to apply
- Test pods to verify behavior
- `README.md` with step-by-step setup and verification

## Cluster

Labs are designed for a multi-node Kubernetes cluster (1 controlplane + workers).
Some configurations assume:
- Cilium as the CNI
- Falco deployed via Helm
- MetalLB + ingress-nginx for Ingress
