# Network Policies Analysis

## Question 1
By default, pods can communicate with each other across namespaces. Verify this by testing connectivity from:
- frontend pod to backend pod
- frontend pod to api pod (development namespace)

Use `kubectl exec` to test.

❯ k -n production get pods -o wide
backend 10.0.1.77
frontend 10.0.1.193

❯ k -n production exec -it pods/backend -c test -- ping 10.0.1.193
PING 10.0.1.193 (10.0.1.193): 56 data bytes
64 bytes from 10.0.1.193: seq=0 ttl=63 time=0.190 ms
64 bytes from 10.0.1.193: seq=1 ttl=63 time=0.092 ms

❯ k -n production exec -it pods/frontend -c test -- ping 10.0.1.77
PING 10.0.1.77 (10.0.1.77): 56 data bytes
64 bytes from 10.0.1.77: seq=0 ttl=63 time=0.096 ms
64 bytes from 10.0.1.77: seq=1 ttl=63 time=0.068 ms

❯ k -n development get pods -o wide
api 10.0.2.47

❯ k -n production exec -it pods/frontend -c test -- ping 10.0.2.47
PING 10.0.2.47 (10.0.2.47): 56 data bytes
64 bytes from 10.0.2.47: seq=0 ttl=63 time=0.440 ms
64 bytes from 10.0.2.47: seq=1 ttl=63 time=0.344 ms

## Question 2
Create a default-deny NetworkPolicy for the `production` namespace. Apply it and verify that:
- Pods inside production cannot communicate anymore
- What happens with existing connections?

❯ cat << EOF >> network.yml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

Existing connections will be terminated (packets will not be sent, if we delete policy, packets will continue sending)

## Question 3
Now create an allow policy that permits:
- frontend -> backend communication on port 80
- Apply and test again

labels:
    app: frontend

❯ cat << EOF >> network1.yml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: q3
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 80
EOF

❯ cat << EOF >> network2.yml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: q3-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
EOF

❯ k -n production exec -it pods/frontend -c test -- curl 10.0.1.77:80

## Question 4
Can traffic from development namespace reach production? What would you need to add to allow or block this?

❯ cat << EOF >> network3.yml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-development
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          env: development
EOF

## Question 5
Install kube-bench and run it:
❯ /tmp/kube-bench --config-dir /tmp/cfg run --version 1.34
...
== Summary node ==
1 checks PASS
11 checks FAIL
13 checks WARN
0 checks INFO
...

## Question 6
Run check 1.2.16:
❯ /tmp/kube-bench --config-dir /tmp/cfg run --version 1.34 --check 1.2.16
[FAIL] 1.2.16 Ensure that the --audit-log-path argument is set (Automated)

Fix: Add to kube-apiserver manifest:
--audit-log-path=/var/log/kubernetes/audit.log

/tmp/kube-bench --config-dir /tmp/cfg run --version 1.34 --check 1.2.16