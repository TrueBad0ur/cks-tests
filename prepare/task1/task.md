# Task 1: RBAC - RoleBinding Analysis

## Objective
Analyze RoleBindings in the `default` namespace to identify security issues.

## Pre-created Resources
All resources are already applied to the cluster. Configs available in `configs/`:
- `configs/serviceaccounts.yaml` - 3 ServiceAccounts
- `configs/roles.yaml` - 4 Roles
- `configs/rolebindings.yaml` - 5 RoleBindings

## Your Task
Analyze the RBAC configuration and answer these questions in `solution.md`:

### Question 1
Which ServiceAccounts can **create** pods in default namespace?

### Question 2  
Which ServiceAccount has **too many permissions** (has multiple RoleBindings that together give excessive access)?

### Question 3
Look at the `developer` ServiceAccount specifically. How many RoleBindings does it have? What are the combined permissions? Is this a security concern?

### Question 4
What would you recommend to fix the security issues found?
