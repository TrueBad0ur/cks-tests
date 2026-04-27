# Kubernetes Auth

## Structure

```
auth/
├── users/
│   ├── alice-rbac.yaml          # Namespace + Role + RoleBinding
│   ├── scripts/
│   │   ├── 01-gen-csr.sh        # Generates key + CSR + submits to k8s
│   │   ├── 02-approve.sh        # Cluster-admin approves + saves cert
│   │   └── 03-kubeconfig.sh     # Builds alice.kubeconfig
└── apps/
    ├── serviceaccount.yaml      # SA my-app
    ├── rbac.yaml                # Role + RoleBinding for SA
    └── pod.yaml                 # Pod with mounted SA token
```

## How it works

**Human users** — Kubernetes has no `User` object. Identity is established via X.509 certificate:
- `CN=alice` → username
- `O=developers` → group
- The cluster signs the certificate via the CSR flow, then you give the person `alice.kubeconfig`

**Applications** — use `ServiceAccount`:
- SA is a real Kubernetes object
- Kubernetes automatically mounts the token into the pod (`/var/run/secrets/kubernetes.io/serviceaccount/token`)
- The application uses it to talk to the API

## Steps for alice

```bash
kubectl apply -f users/alice-rbac.yaml
./users/scripts/01-gen-csr.sh    # submits CSR
./users/scripts/02-approve.sh    # approves (requires cluster-admin)
./users/scripts/03-kubeconfig.sh # creates alice.kubeconfig

# Verify as alice:
KUBECONFIG=tmp/alice.kubeconfig kubectl auth whoami
KUBECONFIG=tmp/alice.kubeconfig kubectl get pods -n auth-demo
KUBECONFIG=tmp/alice.kubeconfig kubectl get pods -n default  # forbidden
```

## Steps for an application

```bash
kubectl apply -f apps/serviceaccount.yaml
kubectl apply -f apps/rbac.yaml
kubectl apply -f apps/pod.yaml

# Inside the pod:
kubectl exec -n auth-demo my-app -- \
  curl -sk -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  https://kubernetes.default/api/v1/namespaces/auth-demo/pods
```
