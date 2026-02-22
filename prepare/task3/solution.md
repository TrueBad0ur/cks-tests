# Secrets & Encryption Analysis

## Question 1
How are secrets stored in Kubernetes? Are they encrypted at rest by default? Prove it.

No, they are not encrypted:
❯ k -n secure-app get secrets db-credentials -o json | jq -r '.data.password' | base64 -d
password123

## Question 2
How can you check if etcd encryption is enabled in this cluster? Is it enabled?

We can check etcd.yaml in static manifests. If it contains --encryption-provider-config flag or not
And also we can try to use etcdctl and access etcd endpoint
looks like it doesn't because:
❯  ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key get / --prefix --keys-only
And I get the results

## Question 3
The secret `db-credentials` uses default Kubernetes secrets (base64 encoded). 
We chose to use SealedSecrets (kubeseal):
- Fetch the public cert
- Seal the existing secret or create a new one
- Apply the SealedSecret to the cluster

Show what you created and explain how it improves security.

❯ k -n secure-app get secrets db-credentials -o yaml > secret.yaml
❯ /tmp/kubeseal < secret.yaml > sealed-secret.json
❯ k apply -f sealed-secret.json


## Question 4
Enable encryption at rest. Create an EncryptionConfiguration file and configure API server to use it. Verify that secrets are encrypted in etcd.

on master node:
❯ head -c 32 /dev/urandom | base64

❯ cat <<EOF >> /etc/kubernetes/enc/enc.yaml
---
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
      - configmaps
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <value from above>
      - identity: {}
EOF

in /etc/kubernetes/manifests/kube-apiserver.yaml:
add parameter: - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml
add:
    volumeMounts:
    ...
    - name: enc
      mountPath: /etc/kubernetes/enc
      readOnly: true
    ...
  volumes:
  ...
  - name: enc
    hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate

❯ kubectl get secrets --all-namespaces -o json | kubectl replace -f -
To check:
❯ kubectl create secret generic secret1 -n default --from-literal=password=PASSWORDAAA
secret/secret1 created

❯ ETCDCTL_API=3 etcdctl    --cacert=/etc/kubernetes/pki/etcd/ca.crt      --cert=/etc/kubernetes/pki/etcd/server.crt    --key=/etc/kubernetes/pki/etcd/server.key     get /registry/secrets/default/secret1 | hexdump -C
00000000  2f 72 65 67 69 73 74 72  79 2f 73 65 63 72 65 74  |/registry/secret|
00000010  73 2f 64 65 66 61 75 6c  74 2f 73 65 63 72 65 74  |s/default/secret|
00000020  32 0a 6b 38 73 3a 65 6e  63 3a 61 65 73 63 62 63  |2.k8s:enc:aescbc| <-- indicates encryption, also we don't see the secret source
00000030  3a 76 31 3a 6b 65 79 31  3a 6c e8 78 86 3a ac d0  |:v1:key1:l.x.:..|
00000040  b4 0a aa e0 72 ba 72 60  86 c6 99 e3 1b f7 34 27  |....r.r`......4'|
00000050  8e c2 28 2a 14 e2 55 c3  ea d0 e4 77 93 23 88 3e  |..(*..U....w.#.>|
00000060  ec d0 37 36 2b 77 5f 20  ad 01 90 b3 40 67 c0 c6  |..76+w_ ....@g..|
00000070  ff bc 67 f8 a0 0a 1d ef  a4 a1 d6 34 0a d9 b0 83  |..g........4....|
00000080  45 c6 f5 c7 85 3d 7b 38  66 3d 43 87 ad a3 87 84  |E....={8f=C.....|
00000090  8a 5b 0b 49 4e 48 1c c5  01 71 af 6c 45 2d 2d 09  |.[.INH...q.lE--.|
000000a0  dc 0b e6 cc 9b e3 69 a4  0b 24 85 06 ef 2d f6 e4  |......i..$...-..|
000000b0  0b ca 3e a9 36 93 91 b3  da 4d 39 3c 48 0e f2 65  |..>.6....M9<H..e|
000000c0  ba a3 8b 9f 80 9c 5f 9a  ab bb 23 27 ab c3 21 23  |......_...#'..!#|
000000d0  9b f2 2b 86 1f 9b 23 80  82 7d dd 55 ed f9 83 9d  |..+...#..}.U....|
000000e0  9c 5e 56 f5 41 77 a0 b4  71 59 a6 d3 58 53 eb 75  |.^V.Aw..qY..XS.u|
000000f0  73 d5 6e 04 fb 86 f7 df  5b 1b 03 c4 7e bf 80 b8  |s.n.....[...~...|
00000100  44 62 a1 96 41 b8 75 c8  c1 6f 1f aa eb 1b 3a 5c  |Db..A.u..o....:\|
00000110  cb 68 c3 22 54 ac e7 08  62 65 37 93 5f 06 46 5e  |.h."T...be7._.F^|
00000120  0e 43 82 ef 3b 92 85 d2  d0 0b f0 76 1b e5 53 67  |.C..;......v..Sg|
00000130  1e 62 a4 90 79 4b d8 31  36 64 f4 57 ef 14 18 68  |.b..yK.16d.W...h|
00000140  8c 96 cd 1d ba 46 47 71  5a 0a                    |.....FGqZ.|
0000014a