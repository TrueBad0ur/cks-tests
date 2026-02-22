# Task 4: Network Policies

## Objective
Analyze and implement Network Policies in Kubernetes.

## Pre-created Resources
All resources are already applied to the cluster:
- Namespace `production` (with pods: frontend, backend)
- Namespace `development` (with pod: api)

## Your Task
Analyze network connectivity and answer in `solution.md`:

### Question 1
By default, pods can communicate with each other across namespaces. Verify this by testing connectivity from:
- frontend pod to backend pod
- frontend pod to api pod (development namespace)

Use `kubectl exec` to test.

### Question 2
Create a default-deny NetworkPolicy for the `production` namespace. Apply it and verify that:
- Pods inside production cannot communicate anymore
- What happens with existing connections?

### Question 3
Now create an allow policy that permits:
- frontend -> backend communication on port 80
- Apply and test again

### Question 4
Can traffic from development namespace reach production? What would you need to add to allow or block this?
