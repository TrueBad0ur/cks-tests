# Task 2: Pod Security Standards (PSS) & Security Context

## Objective
Analyze the `web-app` namespace and identify Pod Security violations.

## Pre-created Resources
All resources are already applied to the cluster. Configs in `configs/`:
- `configs/namespace.yaml` - namespace with PSS labels
- `configs/deployments.yaml` - deployment with security issues
- `configs/warning-pod.yaml` - pod that triggers warnings

## Your Task
Analyze the namespace and resources, then answer in `solution.md`:

### Question 1
What are the Pod Security Standards (PSS) labels applied to `web-app` namespace? What do they mean?

### Question 2
Look at the `web-frontend` deployment. What security issues can you identify in its securityContext?

### Question 3
Look at the `warning-pod` pod. Why was it allowed to create despite the warning? What restricted violations does it have?

### Question 4
If you wanted the pods to pass `restricted` policy (without changing namespace labels), what would you need to change in the deployment's securityContext?

### Question 5
What commands would you use to:
- Check which PSS level is enforced in a namespace?
- List all pods that violate PSS in a namespace?

### Question 6
There's a custom seccomp profile in `configs/chmod-block.json` that blocks chmod syscalls.
There's also a pod manifest in `configs/chmod-blocked-pod.yaml` that uses this profile.

To use a custom seccomp profile:
1. Copy `chmod-block.json` to each node's seccomp directory (e.g., `/var/lib/kubelet/seccomp/`)
2. Apply the pod from `chmod-blocked-pod.yaml`

What happens when you apply the pod?
