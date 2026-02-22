# Task 3: Secrets & Encryption

## Objective
Analyze secrets management and encryption in the cluster.

## Pre-created Resources
All resources are already applied to the cluster:
- Namespace `secure-app`
- Secret `db-credentials` (contains username: admin, password: password123)
- Deployment using this secret

## Your Task
Analyze the secrets configuration and answer in `solution.md`:

### Question 1
How are secrets stored in Kubernetes? Are they encrypted at rest by default? Prove it.

### Question 2
How can you check if etcd encryption is enabled in this cluster? Is it enabled?

### Question 3
The secret `db-credentials` uses default Kubernetes secrets (base64 encoded).
Use SealedSecrets (kubeseal is available at `/tmp/kubeseal`) to create an encrypted SealedSecret.
- Fetch the public cert: `/tmp/kubeseal --fetch-cert` (already saved in configs)
- Seal the existing secret or create a new one
- Apply the SealedSecret to the cluster

Show what you created and explain how it improves security.

### Question 4
Enable encryption at rest. Create an EncryptionConfiguration file and configure API server to use it. Verify that secrets are encrypted in etcd.