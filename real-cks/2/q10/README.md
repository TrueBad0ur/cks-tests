# Q10 — Istio Sidecar Injection

Enable Istio sidecar injection for Namespace `team-sedum` and restart all Pods.

## Verify Istio is installed

```bash
kubectl get namespace istio-system
kubectl -n istio-system get pods
kubectl get mutatingwebhookconfiguration | grep istio
```

## Enable injection on the namespace

```bash
kubectl label namespace team-sedum istio-injection=enabled
# or apply the patch:
kubectl apply -f namespace-patch.yaml
```

Verify:
```bash
kubectl get namespace team-sedum --show-labels
```

## Restart existing Pods to get the sidecar injected

Existing Pods won't get the sidecar automatically — they need to be restarted.

```bash
# List current Deployments
kubectl -n team-sedum get deployments

# Restart all Deployments (triggers rolling restart)
kubectl -n team-sedum rollout restart deployment/one
kubectl -n team-sedum rollout restart deployment/two

# Wait for rollout
kubectl -n team-sedum rollout status deployment/one
kubectl -n team-sedum rollout status deployment/two
```

## Verification

```bash
# Pods should now show 2/2 (app container + istio-proxy)
kubectl -n team-sedum get pods

# Inspect containers in a pod
kubectl -n team-sedum get pod <pod-name> -o jsonpath='{.spec.containers[*].name}'
# Expected: one istio-proxy

# Check sidecar logs
kubectl -n team-sedum logs <pod-name> -c istio-proxy | head -10
```

## How Istio injection works

1. The `istio-injection=enabled` label on the Namespace triggers the Istio `MutatingWebhookConfiguration`
2. On each new Pod creation, the webhook mutates the Pod spec to add:
   - An `initContainer` (`istio-init`) to set up iptables rules
   - A sidecar container (`istio-proxy`) running Envoy
3. All traffic to/from the Pod is intercepted by the proxy, enabling mTLS and observability
