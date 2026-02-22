# Pod Security Standards Analysis - web-app namespace

## Question 1
PSS labels and their meaning:
❯ k get ns web-app -o yaml
...
"pod-security.kubernetes.io/audit":"restricted"
"pod-security.kubernetes.io/enforce":"baseline"
"pod-security.kubernetes.io/warn":"restricted"
...
It means that restricted PSS is enabled in audit mode (doesn't prevent pods from running, but keep audit logs), baseline PSS is enabled in enforce mode (prevent pods from running), and also restricted PSS is enabled in warn mode, so the user will get message when he tries to apply anything

## Question 2
Security issues in web-frontend deployment securityContext:
❯ k -n web-app get deployments.apps web-frontend -o yaml | grep "securityContext:" -A 5 | head -n 4
        securityContext:
          allowPrivilegeEscalation: true
          readOnlyRootFilesystem: false
          runAsNonRoot: false

**allowPrivilegeEscalation: true** violates baseline
**readOnlyRootFilesystem: false** violates restricted
**runAsNonRoot: false** violates restricted

## Question 3
Why warning-pod was allowed and what restricted violations it has:
❯ k apply -f warning-pod.yaml

Warning: would violate PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "test" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "test" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (container "test" must not set securityContext.runAsNonRoot=false), seccompProfile (pod or container "test" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")

So it violates restricted PPS because of:
allowPrivilegeEscalation: true
it doesn't drop all capabilities
runAsNonRoot = false
it doesn't set any seccompProfile

## Question 4
If you wanted the pods to pass `restricted` policy (without changing namespace labels), what would you need to change in the deployment's securityContext?

You need to change the following:
- allowPrivilegeEscalation: false
- runAsNonRoot: true  
- capabilities.drop: ["ALL"]
- seccompProfile.type: RuntimeDefault

## Question 5
Commands for PSS:
- Check PSS level in namespace:
- List pods that violate PSS:

To check which policy is enabled in enforce mode for namespace I'll do:
❯ k get ns web-app -o json | jq '.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration"' | jq -r | jq '.metadata.labels'
{
  "pod-security.kubernetes.io/audit": "restricted",
  "pod-security.kubernetes.io/enforce": "baseline",
  "pod-security.kubernetes.io/warn": "restricted"
}

To find out violating pods the simplest way is to apply and get the results