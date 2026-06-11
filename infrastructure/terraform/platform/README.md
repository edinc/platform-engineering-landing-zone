# Platform shared services (Stage 04)

Initial Terraform composition for the core shared services that later platform
stages and workload golden paths consume.

Related decisions: ADR-0003 (ingress seed), ADR-0009 (AKS dataplane seed),
ADR-0010 (AKS autoscaling seed), ADR-0012 (Backstage hosting seed),
ADR-0017 (DR posture seed), [ADR-0032](../../../docs/adr/0032-platform-eventing.md),
and [ADR-0050](../../../docs/adr/0050-aca-managed-environment.md).

## What this stack owns

| Capability | Resource | Notes |
|------------|----------|-------|
| Platform spoke network | `azurerm_virtual_network`, subnets, NSGs, optional UDR | UDR points to the Stage 03 firewall when `firewall_private_ip_address` is set. |
| AKS | `azurerm_kubernetes_cluster`, user pool, AKS identity | Private, local accounts disabled, Entra/Azure RBAC, Workload Identity, OIDC, Azure CNI Overlay + Cilium, image cleaner, stable auto-upgrade channel. |
| ACR | `azurerm_container_registry`, cache rules | Premium, public access disabled, admin disabled, retention 14d, optional geo-replication. |
| Key Vault | `azurerm_key_vault` | RBAC mode, purge protection, soft-delete 90d, public access disabled. |
| Postgres | `azurerm_postgresql_flexible_server` | Optional until a secret source is wired; delegated subnet, private DNS, backstage database. |
| Service Bus | `azurerm_servicebus_namespace` | Premium, local auth disabled, public access disabled. |
| ACA substrate | `azurerm_container_app_environment` | VNet-injected, internal load balancer, workload profiles for prod. |
| Edge shell | Front Door Premium profile + WAF policy | WAF starts in Detection mode; origins/PLS are completed when ingress-nginx exists. |
| Private Endpoints | `azurerm_private_endpoint` | ACR, Key Vault, and Service Bus when Stage 03 Private DNS zone IDs are supplied. |

## Deliberate initial-slice boundaries

- AKS Backup, ACR Tasks private agent pools, Postgres CMK, Front Door Private
  Link origin, ingress-nginx, and smoke-test apps are documented Stage 04
  follow-ups. This slice wires the deployable substrate and output contracts.
- AKS Node Auto-Provisioning is not exposed by the current `azurerm` provider
  schema used here; user-pool cluster autoscaler is enabled as the current
  Terraform-managed baseline and NAP remains a follow-up when provider support is
  available.
- `enable_postgres` defaults to `false` because password auth still requires an
  out-of-band secret input. Enable it only through a secret-backed pipeline
  variable until passwordless/Entra auth is completed in a later stage.
- AMPLS is owned by Stage 03 connectivity. This stack consumes the Log Analytics
  workspace ID for integrations only.

## State backend

State lives in the Stage 01 account, container `platform`, with a key such as
`nonprod/platform.tfstate`. Copy `backend.hcl.example` to `backend.hcl`, fill
`resource_group_name` and `storage_account_name` from `_bootstrap` outputs, then:

```bash
terraform init -backend-config=backend.hcl
```

CI validates credential-free with `terraform init -backend=false`.

## Required Stage 03 inputs

| Input | Purpose |
|-------|---------|
| `private_dns_zone_ids` | Private DNS zone IDs for ACR, Key Vault, Postgres, Service Bus, and AKS API. |
| `private_dns_zone_subscription_id` | Subscription that owns the supplied Private DNS zones; set to the Stage 03 connectivity subscription for centralized zones. |
| `firewall_private_ip_address` | Enables platform subnet UDRs to Stage 03 Firewall. |
| `log_analytics_workspace_id` | Enables Defender/OMS/ACA logging integrations. |
| `aks_host_encryption_enabled` | Keep `true` for production; set `false` only in demo subscriptions where EncryptionAtHost is unavailable. |

## Validation

```bash
make terraform-validate
make lint checkov
```

## Acceptance-criteria mapping

| # | Criterion | Current status |
|---|-----------|----------------|
| 1 | AKS private/RBAC/WI/Defender/planned-maintenance/image-cleaner baseline | Implemented for private/RBAC/WI/OIDC/Cilium/image-cleaner/maintenance; Defender is enabled when a workspace is supplied; AKS Backup remains follow-up. |
| 2 | ACR Artifact Cache and quay import workflow | Cache rule contract added for unauthenticated supported sources; Docker Hub requires credentials and quay import uses `workflows/import-quay.yml`; ACR trusted-service bypass stays enabled so `az acr import` can run while public access is disabled. |
| 3 | Backstage Postgres DB private | Optional Postgres + `backstage` database implemented; CMK rotation remains follow-up. |
| 4 | Front Door + ingress-nginx PLS | Front Door Premium + WAF shell implemented; ingress-nginx/PLS origin waits for in-cluster Stage 07. |
| 5 | Cluster-state repo | Implemented in sibling `../cluster-state-repo/` composition. |
| 6 | ACA managed environment | Implemented; app smoke test waits for golden-path/runtime stage. |
| 7 | Service Bus namespace | Implemented with public access and local auth disabled. |
| 8 | DR matrix | Added in `docs/runbooks/dr-matrix.md`; Stage 12 validates drills. |
