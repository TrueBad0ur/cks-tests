# RBAC Analysis - Default Namespace

## Question 1
Which ServiceAccounts can **create** pods in default namespace?

❯ k get rolebindings.rbac.authorization.k8s.io
NAME                       ROLE                  AGE
app-deployer-binding       Role/pod-creator      8m14s
app-reader-binding         Role/pod-reader       8m14s
developer-admin-binding    Role/admin-like       8m14s
developer-pod-binding      Role/pod-creator      8m14s
developer-secret-binding   Role/secret-manager   8m14s

❯ for i in $(k get sa -n default | awk '{print $1}' | tail -n +2); do echo $i; k auth can-i create pods --as=system:serviceaccount:default:$i; echo; done    
app-deployer
yes

app-reader
no

argocd-redis-secret-init
no

default
no

developer
yes

## Question 2
Which ServiceAccount has too many permissions (has multiple RoleBindings that together give excessive access)?

❯ for i in $(k get rolebindings.rbac.authorization.k8s.io -n default | awk '{print $1}' | tail -n +2); do echo "RoleBinding: $i"; k describe rolebindings.rbac.authorization.k8s.io $i | grep ServiceAccount; echo; done;
RoleBinding: app-deployer-binding
  ServiceAccount  app-deployer  default

RoleBinding: app-reader-binding
  ServiceAccount  app-reader  default

RoleBinding: developer-admin-binding
  ServiceAccount  developer  default

RoleBinding: developer-pod-binding
  ServiceAccount  developer  default

RoleBinding: developer-secret-binding
  ServiceAccount  developer  default

Looks like the answer is **developer** 

## Question 3
Look at the `developer` ServiceAccount specifically. How many RoleBindings does it have? What are the combined permissions? Is this a security concern?

❯ k get rolebindings.rbac.authorization.k8s.io developer-admin-binding -o json | jq ".roleRef.name"
"admin-like"

❯ k get rolebindings.rbac.authorization.k8s.io developer-pod-binding -o json | jq ".roleRef.name"
"pod-creator"

❯ k get rolebindings.rbac.authorization.k8s.io developer-secret-binding -o json | jq ".roleRef.name"
"secret-manager"

❯ k get role admin-like -o yaml
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - services
  - configmaps
  - secrets
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - delete
  - patch

❯ k get role pod-creator -o yaml
rules:
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - create
  - delete

❯ k get role secret-manager -o yaml
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - create
  - update
  - delete

From the result **admin-like** role is too wide, so it should not be given to user
And also there are duplicates in rights, so it's not okay

## Question 4
What would you recommend to fix the security issues found?

Delete **developer-admin-binding**, role **admin-like** is too wide
Best practice will be to create minimum width roles, if we need deploy - keep pod-creator, if need secrets - secret-manager
