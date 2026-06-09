# Terraform

Terraform is the primary IaC language for Azure landing-zone and platform
shared infrastructure.

| Directory | Stage | Purpose |
|-----------|-------|---------|
| `_bootstrap/` | Stage 01 | Remote state, OIDC federation, and seed Key Vault. |
| `_modules/` | All | Reusable AVM-aligned modules. |
| `alz/` | Stage 02 | Management groups, policy, Defender, and logging baseline. |
| `connectivity/` | Stage 03 | Hub networking, egress, Private DNS, and Private Link standards. |
| `identity/` | Stage 03 | Entra-supported platform identities and access model. |
| `platform/` | Stage 04 | AKS, ACR, Key Vault, Postgres, ingress, and shared services. |
| `vending/` | Stage 05 | Subscription and environment vending compositions. |
| `envs/` | All | Profile-specific composition for `demo`, `nonprod`, and `prod`. |
