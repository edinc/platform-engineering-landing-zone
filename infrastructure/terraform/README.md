# Terraform

Terraform is the primary IaC language for Azure landing-zone and platform
shared infrastructure.

| Directory | Capability | Purpose |
|-----------|-------|---------|
| `_bootstrap/` | Azure foundation | Remote state, OIDC federation, and seed Key Vault. |
| `_modules/` | All | Reusable AVM-aligned modules. |
| `subscription-baseline/` | subscription baseline | Existing-subscription hardening: Defender, Activity Log diagnostics, budgets, and cost export wiring. |
| `connectivity/` | connectivity & egress | Hub networking, egress, Private DNS, and Private Link standards. |
| `identity/` | connectivity & egress | Entra-supported platform identities and access model. |
| `platform/` | platform shared services | AKS, ACR, Key Vault, Postgres, ingress, and shared services. |
| `vending/` | tenancy vending | Subscription and environment vending compositions. |
| `envs/` | All | Profile-specific composition for `demo`, `nonprod`, and `prod`. |
