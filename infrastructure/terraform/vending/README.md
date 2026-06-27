# Vending Terraform (tenancy vending)

Terraform-first vending and onboarding compositions for the platform landing
zone.

Related decisions: [ADR-0008](../../../docs/adr/0008-subscription-vending.md),
[ADR-0033](../../../docs/adr/0033-aks-namespace-vending.md),
[ADR-0034](../../../docs/adr/0034-vending-request-schema.md), and
[ADR-0051](../../../docs/adr/0051-cross-repo-github-writes.md).

## Compositions

| Path | Purpose |
| --- | --- |
| [`subscription/`](subscription/) | Repo-owned workload subscription creation with `Azure/lz-vending` pinned to commit `dee26d39d5d3fc5fb78feb7fe26d63e4d956c9be` (`v4.1.5`). |
| [`onboarding/`](onboarding/) | Handoff bundle for externally-created subscriptions before subscription baseline. |
| [`aks-namespace/`](aks-namespace/) | Workload identity, ACR/KV access, and Flux-compatible namespace manifests. |

## State backend

State lives in the Azure foundation state account, container `vending`. Use keys such as:

- `subscriptions/<team>-<env>/terraform.tfstate`
- `onboarding/<subscription-id>/terraform.tfstate`
- `namespaces/<team>/<env>/<namespace>/terraform.tfstate`

Copy a stack-specific `backend.hcl`, fill `resource_group_name` and
`storage_account_name` from `_bootstrap` outputs, then run `terraform init
-backend-config=backend.hcl`. CI validates credential-free with
`terraform init -backend=false`.

## Acceptance-criteria mapping

| # | Criterion | Where |
| --- | --- | --- |
| 1 | Subscription request plans/applies through PR approval | `subscription/`, `onboarding/`, `.github/workflows/vend-subscription.yml` |
| 2 | Namespace request opens a platform-cluster-state PR as the vending bot | `aks-namespace/`, `.github/workflows/vend-namespace.yml` |
| 3 | Flux reconciliation of vended namespace | Manifest bundle emitted by `aks-namespace/`; reconciliation is validated in GitOps platform |
| 4 | Versioned schema rejects incompatible fields | `docs/contracts/` and `make contract-test` |
| 5 | GitHub App private key stays in seed Key Vault | `../github-app/` and `docs/runbooks/vending.md` |
