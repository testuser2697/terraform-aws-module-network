# AWS Advanced Terraform Training Repository

© 2026 Michael Coulling-Green — QA

# Network Module

## Purpose

The Network module provisions the shared AWS networking foundation used by downstream modules.

Resources managed by this module include:

* VPC
* Subnets
* Route Table
* Route Table Associations
* Security Group
* Security Group Rules

The module is designed to be self-contained and reusable. All networking assumptions, validation, and sanitization should be owned by the module itself.

---

## Inputs

| Variable             | Description                              |
| -------------------- | ---------------------------------------- |
| prefix               | Naming prefix applied to resources       |
| base_tags            | Common tags applied to all resources     |
| region               | AWS region                               |
| vpc_cidr             | CIDR block used by the VPC               |
| subnet_cidrs         | Map of subnet CIDRs                      |
| allow_groups         | Named CIDR groups used by security rules |
| security_group_rules | Security group rule definitions          |

---

## Outputs

| Output            | Description                                     |
| ----------------- | ----------------------------------------------- |
| app_subnet_id     | Application subnet ID used by compute resources |
| security_group_id | Security group ID used by compute resources     |

---

## Design Principles

This module owns responsibility for:

* Networking resource creation
* Validation of networking inputs
* Sanitization of networking data structures
* Exposure of networking values required by consumers

Modules should expose only the values required by consumers rather than every internal resource identifier.

---

## Example Usage

```hcl
module "network" {
  source = "./modules/network"

  prefix               = local.prefix
  base_tags            = local.base_tags
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  subnet_cidrs         = var.subnet_cidrs
  allow_groups         = var.allow_groups
  security_group_rules = var.security_group_rules
}
```

---

## Typical Consumers

Examples of modules that may consume outputs from this module include:

* Compute Modules
* Database Modules
* Kubernetes Modules
* Load Balancer Modules

Consumers should interact through module outputs rather than referencing internal resources directly.
