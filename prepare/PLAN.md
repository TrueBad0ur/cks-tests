# CKS Exam Preparation Plan

## Exam Topics Coverage (based on CNCF CKS curriculum)

| Domain | Weight | My Focus |
|--------|--------|----------|
| 1. Cluster Setup | 10% | Secure kubeadm, CIS benchmarks, etcd encryption |
| 2. Cluster Hardening | 15% | RBAC, ServiceAccounts, API server flags, secrets |
| 3. System Hardening | 15% | AppArmor, seccomp, kernel parameters, update management |
| 4. Minimize Microservice Vulnerabilities | 15% | NetworkPolicies, mTLS (Istio), security contexts |
| 5. Supply Chain Security | 20% | Image scanning, sigstore/cosign, secure base images |
| 6. Monitoring & Runtime Security | 20% | Falco, audit logs, Pod Security Standards |

---

## Learning Approach

### Phase 1: Topic-by-Topic Learning (3-4 days)
- For each topic: theory + hands-on lab in the cluster
- Create flashcards/review notes in `prepare/topics/`
- Run real commands, validate understanding

### Phase 2: Practice Exams (1-2 days)
- Use tasks from `generated-tasks-under-maintenance/`
- Simulate exam conditions
- Time-boxed problem solving

### Phase 3: Weak Areas Review (1 day)
- Focus on topics where score < 80%
- Additional practice and documentation

---

## Daily Structure (for 5-6 days)

```
1. Brief theory intro (5-10 min)
2. Hands-on lab in cluster (20-30 min)
3. Q&A / self-check questions
4. Quick review notes
```

---

## Topics Sequence (suggested)

1. **Day 1**: Cluster Setup & Hardening
   - API Server secure flags
   - RBAC (Role/ClusterRole, RoleBinding/ClusterRoleBinding)
   - ServiceAccount best practices

2. **Day 2**: Secrets & Encryption
   - Secrets management
   - etcd encryption
   - External secrets operators

3. **Day 3**: Pod Security
   - Security Contexts
   - Pod Security Standards (PSS)
   - AppArmor / seccomp

4. **Day 4**: Network Security
   - NetworkPolicies
   - Service Mesh (optional)
   - CIS benchmarks

5. **Day 5**: Supply Chain
   - Trivy image scanning
   - Cosign image signing
   - SBOM generation

6. **Day 6**: Runtime Security
   - Falco rules
   - Audit logs
   - Tetragon basics

---

## What I Will Do

1. Create study materials in `prepare/`
2. Explain each topic with examples
3. Run live demos in the cluster
4. Quiz you with practical tasks
5. Track progress

## What You Will Do

1. Answer questions
2. Execute commands I give you
3. Solve mini-tasks
4. Tell me when something is unclear

---

## Initial Assessment

Before we start, tell me:
- Your current K8s experience level?
- Have you passed CKA already?
- Which topics do you feel weakest in?
- How many hours per day can you dedicate?
