# Runbook: Environment and subscription vending (Stage 05)

This runbook operates the PR-driven vending path for workload subscriptions and
AKS workload namespaces.

Related decisions: [ADR-0008](../adr/0008-subscription-vending.md),
[ADR-0033](../adr/0033-aks-namespace-vending.md),
[ADR-0034](../adr/0034-vending-request-schema.md), and
[ADR-0051](../adr/0051-cross-repo-github-writes.md).

## Prerequisites

| Requirement | Purpose |
| --- | --- |
| Stage 01 seed Key Vault | Stores the `platform-vending-bot` private key. |
| Stage 02 subscription baseline | Hardens new or externally-created subscriptions after vending. |
| Stage 03 connectivity outputs | Supplies hub VNet IDs for workload spoke peering. |
| Stage 04 platform outputs | Supplies AKS OIDC issuer URL, ACR ID, Key Vault ID, and platform resource group. |
| EA/MCA/MPA billing scope | Required when this repo creates subscriptions through `Azure/lz-vending`. |
| `platform-cluster-state` repository | Receives namespace manifests for Flux reconciliation. |

For subscription creation, record the billing scope in the protected `vending`
GitHub environment as an environment variable or in the request source system.
Supported forms include:

- EA:
  `/providers/Microsoft.Billing/billingAccounts/<billing-account>/enrollmentAccounts/<enrollment-account>`
- MCA:
  `/providers/Microsoft.Billing/billingAccounts/<billing-account>/billingProfiles/<profile>/invoiceSections/<section>`
- MPA:
  `/providers/Microsoft.Billing/billingAccounts/<billing-account>/customers/<customer>`

## 1. Create the platform-vending-bot GitHub App

Create a GitHub App named `platform-vending-bot` under the repository owner or
organization.

| Permission | Level | Reason |
| --- | --- | --- |
| Contents | Read/write | Push tenant manifest branches to `platform-cluster-state`. |
| Pull requests | Read/write | Open and update namespace vending PRs. |
| Issues | Read/write | Create or assign PR labels when needed. |
| Metadata | Read | Required by GitHub Apps. |

Install it on:

1. `platform-engineering-landing-zone`
2. `platform-cluster-state`

Generate a private key and immediately load it into the seed Key Vault. Do not
store the PEM in GitHub secrets, commit it, or pass it through Terraform
variables.

```bash
az keyvault secret set \
  --vault-name "<seed-key-vault-name>" \
  --name "platform-vending-bot-private-key" \
  --file ./platform-vending-bot.private-key.pem \
  --content-type "application/x-pem-file" \
  --expires "2026-12-08T00:00:00Z" \
  --only-show-errors
rm -f ./platform-vending-bot.private-key.pem
```

## 2. Apply GitHub App Terraform wiring

From `infrastructure/terraform/github-app/`, initialize remote state using the
Stage 01 state account and apply with protected operator input:

```bash
terraform init -backend-config=backend.hcl
terraform apply \
  -var seed_key_vault_id="<seed-key-vault-id>" \
  -var github_app_id="<app-id>" \
  -var github_app_installation_id="<installation-id>" \
  -var private_key_secret_name="platform-vending-bot-private-key" \
  -var private_key_rotation_due_date="2026-12-08"
```

Set these protected `vending` environment variables for workflows:

| Variable | Source |
| --- | --- |
| `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` | Stage 01 OIDC/bootstrap output |
| `TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`, `TFSTATE_CONTAINER` | Stage 01 backend output |
| `APPROVED_SUBSCRIPTION_MANAGEMENT_GROUP_IDS` | Comma-separated ALZ management group IDs approved for subscription vending |
| `SEED_KEY_VAULT_NAME` | Stage 01 Key Vault output |
| `PLATFORM_VENDING_BOT_APP_ID` | `github-app` output |
| `PLATFORM_VENDING_BOT_INSTALLATION_ID` | `github-app` output |
| `PLATFORM_VENDING_BOT_PRIVATE_KEY_SECRET_NAME` | `github-app` output |
| `CLUSTER_STATE_REPO_OWNER`, `CLUSTER_STATE_REPO_NAME` | Stage 04 cluster-state repo output |
| `AKS_OIDC_ISSUER_URL`, `PLATFORM_AKS_CLUSTER_ID`, `PLATFORM_ACR_ID`, `PLATFORM_KEY_VAULT_SECRET_IDS`, `PLATFORM_RESOURCE_GROUP_NAME` | Stage 04 platform output and approved per-workload secret IDs |
| `VENDING_PR_LABELS`, `VENDING_PR_REVIEWERS` | Optional PR routing controls |

## 3. Vend a workload subscription

Create a `SubscriptionVendingRequest` YAML under
`vending/requests/subscriptions/` using
[`docs/contracts/vending-request.yaml`](../contracts/vending-request.yaml) as
the template.

1. Open a PR with the request.
2. Confirm `vend-subscription.yml` validates the schema and produces a green
   Terraform plan.
3. Reviewers confirm billing scope, management group ID, cost center, data
   classification, budget contacts, and network CIDR.
4. Merge after approval. The `vending` environment approval protects the apply.
5. Run the Stage 02 subscription baseline with the emitted handoff.

For externally-created subscriptions, use
`mode: onboard-existing` and include `existingSubscriptionId` plus
`alzPlacementEvidence`. The workflow runs the onboarding composition instead of
creating a subscription.

## 4. Vend an AKS workload namespace

Create a `NamespaceVendingRequest` YAML under
`vending/requests/namespaces/` using
[`docs/contracts/examples/namespace-request.yaml`](../contracts/examples/namespace-request.yaml)
as the template.

1. Open a PR with the request.
2. Confirm `vend-namespace.yml` validates the schema and plans the Azure
   workload identity, ACR role assignment, Key Vault role assignment,
   namespace-scoped AKS RBAC Reader assignment, and rendered manifests.
3. Merge after approval. The workflow applies the identity/role resources, fetches
   the GitHub App private key from Key Vault, opens a `platform-cluster-state` PR
   under `tenants/<team>/<env>/`, indexes the privileged namespace bootstrap
   path, and then indexes the tenant-scoped Flux Kustomization under
   `clusters/overlays/<env>/tenants/`.
   The workflow syncs only the generated `bootstrap/` directory with `--delete`;
   tenant-owned `workloads/` files are never deleted by namespace re-vending.
   Tenant write access is intentionally GitOps-first; direct Entra access is
   reader-only, the native Kubernetes RoleBinding is read-only, and
   NetworkPolicy changes remain platform-controlled.
4. Review and merge the cluster-state PR after its CI passes.
5. Stage 07 validates Flux reconciliation and Kyverno policy enforcement through
   namespace-scoped Flux impersonation.

## 5. Rotate the GitHub App private key

1. Generate a new private key for `platform-vending-bot`.
2. Write it to the same seed Key Vault secret with a new `--expires` value.
3. Re-apply `infrastructure/terraform/github-app/` with the new
   `private_key_rotation_due_date`.
4. Run `vend-namespace.yml` against a non-production namespace request with
   `workflow_dispatch`; then merge a reviewed request to `main` if the plan is
   expected.
5. Confirm the App opens or updates the `platform-cluster-state` PR.
6. Delete the old private key from the GitHub App settings after the workflow
   succeeds.

## Stage 06 reusable-workflow refactor checklist

Stage 05 ships standalone workflows. When Stage 06 reusable workflows land:

1. Move schema validation into the shared workflow.
2. Replace inline Terraform init/validate/plan/apply steps with the Stage 06
   reusable Terraform workflow.
3. Keep GitHub App token creation and cluster-state PR creation in the namespace
   caller unless Stage 06 adds a dedicated cross-repo PR reusable workflow.
4. Preserve the same `docs/contracts/vending-request.schema.json` contract.

## Rollback

- Subscription creation rollback follows the `Azure/lz-vending` state lifecycle
  and must be approved by the ALZ/billing owner before cancellation.
- Existing-subscription onboarding rollback uses the
  [subscription onboarding runbook](subscription-onboarding.md).
- Namespace rollback removes the tenant manifests from `platform-cluster-state`
  and then destroys the matching `vending/aks-namespace` Terraform state after
  Flux has pruned the namespace.
