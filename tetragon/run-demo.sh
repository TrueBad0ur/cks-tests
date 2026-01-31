# helm install tetragon cilium/tetragon -n kube-system --set tetragon.enablePolicyFilter=true

kubectl apply -f "./pods/"
kubectl apply -f "./01-process-exec.yaml"
kubectl apply -f "./02-tcp-connect.yaml"
kubectl apply -f "./03-binary-exec-common.yaml"
kubectl apply -f "./04-tcp-pod-network.yaml"
kubectl apply -f "./05-file-open.yaml"
kubectl apply -f "./06-syscall-write.yaml"
kubectl apply -f "./07-commit-creds.yaml"
kubectl apply -f "./08-sys-mount.yaml"
kubectl apply -f "./09-sys-ptrace.yaml"

kubectl wait --for=condition=Ready pod/client-curl pod/client-busybox pod/server-nginx pod/client-mount pod/client-strace --timeout=60s 2>/dev/null || true

NODE=$(kubectl get pod client-curl -o jsonpath='{.spec.nodeName}')
kubectl exec -n kube-system -it $(kubectl get pods -n kube-system -l app.kubernetes.io/name=tetragon --field-selector spec.nodeName=$NODE -o jsonpath='{.items[0].metadata.name}') -c tetragon -- tetra getevents -o compact --policy-names process-exec --policy-names tcp-connect --policy-names binary-exec-common --policy-names tcp-pod-network --policy-names file-open --policy-names syscall-write --policy-names commit-creds --policy-names sys-mount --policy-names sys-ptrace

kubectl exec -it client-curl -- curl -s https://example.com
kubectl exec -it client-busybox -- wget -q -O- https://example.com
kubectl exec -it client-busybox -- cat /etc/hostname
kubectl exec -it client-busybox -- ls /
kubectl exec -it client-curl -- curl -s http://server-nginx
kubectl exec -it client-busybox -- nc -zv server-nginx 80
kubectl exec -it client-busybox -- cat /etc/passwd
kubectl exec -it client-busybox -- sh -c 'echo foo > /tmp/bar'
kubectl exec -it client-busybox -- ping -c 1 8.8.8.8
kubectl exec -it client-mount -- mount -t tmpfs tmpfs /tmp/mnt
kubectl exec -it client-strace -- sh -c 'apk add -q strace 2>/dev/null; strace -p 1 -e trace=none & sleep 2; kill %1 2>/dev/null'