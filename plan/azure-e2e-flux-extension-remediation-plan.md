# Azure E2E deployment remediation plan: Flux extension migration failure

## Status: code remediation implemented (updated 2026-06-25)

The IaC/code remediation described in this plan has been implemented and merged
in PR #23 (`ef820a5`, "fix: add Flux extension recovery path"), which landed
shortly after this plan was written. The implementation deliverables in
section 5 are complete and pass repository validation
(`python3 scripts/gitops/validate_stage07_gitops.py` → "Stage 07 GitOps
contracts validated.").

Implemented and verified in-repo:

- [x] `recreate_flux_extension_epoch` variable
  (`infrastructure/terraform/platform/variables.tf`).
- [x] `terraform_data.flux_extension_recreate_epoch` trigger
  (`infrastructure/terraform/platform/gitops.tf`).
- [x] `replace_triggered_by` wired on the Flux extension and **both** Flux
  configuration resources (`azurerm_kubernetes_cluster_extension.flux`,
  `azurerm_kubernetes_flux_configuration.platform`,
  `azurerm_kubernetes_flux_configuration.backstage`).
- [x] No stale object-level keys remain in `gitops.tf`
  (`source-controller.featureGates`, `sourceController.featureGates`,
  `ObjectLevelWorkloadIdentity`).
- [x] Regression guard in `scripts/gitops/validate_stage07_gitops.py`
  (`require_not_contains` for each stale key plus the migration variable
  assertion).
- [x] Runbook `docs/runbooks/flux-extension-recovery.md`.
- [x] ADR `docs/adr/0054-flux-controller-workload-identity-migration.md`
  (Status: accepted).

This satisfies acceptance criteria **7, 8, and 9** (runbook, ADR, and Stage 07
regression guard).

Still operator/deployment-dependent (cannot be confirmed from the repository):
acceptance criteria **1–6 and 10** are live-Azure outcomes. They require running
the platform Terraform apply once with the migration epoch set
(`recreate_flux_extension_epoch = "2026-06-flux-controller-wi"` in the protected
platform tfvars), then a second plan with the epoch unchanged showing no repeat
replacement. Verify these against the live `aks-pe-demo-sec` cluster using the
commands in section 7 (or confirm they were already run during the post-merge
deployment).

The remainder of this document is retained as the original failure analysis and
implementation plan for historical context.

## Current outcome

The post-merge deployment did not reach a working end-to-end state.

What succeeded:

- Main `Repository quality gates` completed successfully at commit `6a4f88f`.
- Main `Backstage CI` completed successfully and published the required artifacts:
  - Backstage image digest: `sha256:745120f001948c5e8d679917436b6ccd6c6bb2118cbc241beb15afe8a974f3c5`
  - Backstage catalog reconciler image digest: `sha256:4959f66cf8317b654cfec9d04cc7935fc56c8647e1be84710b7fb571f19c1aad`
  - Backstage chart digest: `sha256:21e49682ac8ec5676c84b846e2a2e2e2f9f2a9382b9acc7a96e59923b066bd06`
- Protected `TERRAFORM_TFVARS_PLATFORM_JSON` was updated with those digests and the intended GitOps settings.
- `platform-gitops/` from `main` was synced to `edinc/platform-cluster-state` at commit `7e3a187`.
- Platform Terraform plan succeeded.

What failed:

- Platform Terraform apply failed while updating the existing `microsoft.flux` AKS extension.
- No code changes were made after this failure, per instruction.

## Root cause

The AKS `microsoft.flux` extension contains persisted configuration keys from the earlier object-level workload identity experiment and new controller-level workload identity keys from the latest design.

Current live extension settings include both:

```text
source-controller.featureGates = ObjectLevelWorkloadIdentity=true
sourceController.featureGates = ObjectLevelWorkloadIdentity=true
sourceController.featureGates.ObjectLevelWorkloadIdentity = true
workloadIdentity.enable = true
workloadIdentity.azureClientId = 01a50dd5-8b1f-462e-b62c-7639b5be8ba3
workloadIdentity.azureTenantId = 6a22959d-d273-4520-9c95-6067b79b36a5
```

The Terraform code now wants only the controller-level workload identity keys:

```text
workloadIdentity.enable = true
workloadIdentity.azureClientId = <flux-source client id>
workloadIdentity.azureTenantId = <tenant id>
```

The Azure extension update failed with:

```text
ExtensionOperationFailed
Error occurred while parsing the helm values for the helm operation
failed parsing --set data: unable to parse key: interface conversion:
interface {} is string, not map[string]interface {}
```

This matches a Helm `--set` merge conflict: one persisted setting treats `sourceController.featureGates` as a scalar string, while another treats `sourceController.featureGates.ObjectLevelWorkloadIdentity` as a nested map path. Azure CLI supports setting extension configuration values but does not expose a clear unset/remove operation for stale configuration keys.

Microsoft Learn documents that deleting the Flux extension removes both the Azure extension resource and the Flux extension objects in the cluster. It also warns to delete all Flux configurations before deleting the extension. For AKS, the documented command is:

```bash
az k8s-extension delete -g <resource-group> -c <cluster-name> -n flux -t managedClusters --yes
```

Reference:

- https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2#delete-the-flux-configuration-and-extension
- https://learn.microsoft.com/azure/azure-arc/kubernetes/conceptual-gitops-flux2#flux-cluster-extension
- https://learn.microsoft.com/azure/azure-arc/kubernetes/extensions-troubleshooting

## Current Azure/GitOps state

Azure resources are up:

- AKS `aks-pe-demo-sec`: `Running` / `Succeeded`
- PostgreSQL `pg-pe-demo-sec-eb64p4`: `Ready`
- Runner VM `ghr-pe-demo-sec-01`: `VM running`, agent `Ready`

Terraform apply partially created:

- Managed identity `id-pe-demo-sec-flux-source`
  - Client ID: `01a50dd5-8b1f-462e-b62c-7639b5be8ba3`
  - Principal ID: `baedd17b-6f23-48d2-b4e3-8e4835e23f66`
- `AcrPull` role assignment for that identity on `acrpedemosec001`

The live Flux extension shows `Succeeded`, and `source-controller` service account is annotated with the new workload identity client ID. However, Terraform did not complete successfully and the Flux configurations remain stale:

- `platform-demo`
  - Still lacks `platform_acr_login_server`
  - Still includes removed `otel_trace_sampling_percentage`
  - Still has stale `cluster_state_repository_provider = github` in postBuild substitution even though the source itself is now SSH/generic
- `backstage-demo`
  - Still points to stale Backstage image, reconciler, and chart digests

Current in-cluster failures:

```text
platform-demo-cluster-demo:
  post build failed for 'platform-config':
  variable not set (strict mode): "platform_acr_login_server"

platform-config:
  post build failed for 'require-tenant-gitops-guardrails':
  variable not set (strict mode): "github_owner"

backstage HelmRelease:
  OCIRepository 'backstage/backstage-chart' is not ready:
  to use spec.serviceAccountName for provider authentication please enable
  the ObjectLevelWorkloadIdentity feature gate in the controller
```

## Implementation plan

### 1. Add a controlled IaC-driven Flux extension migration path

The durable fix should be IaC-driven and explicitly documented as a one-time migration, not an ad hoc portal/manual operation. The migration must replace the Flux configurations and the Flux extension together so Terraform deletes the Flux configurations before deleting the extension, then recreates the extension before recreating the configurations.

Recommended implementation:

1. Add a narrowly scoped migration variable to `infrastructure/terraform/platform`, for example:

   ```hcl
   variable "recreate_flux_extension_epoch" {
     type        = string
     default     = ""
     description = "Optional one-time migration token used to force replacement of the microsoft.flux extension when stale extension Helm values cannot be removed in-place."
   }
   ```

2. Add a `terraform_data` trigger resource:

   ```hcl
   resource "terraform_data" "flux_extension_recreate_epoch" {
     input = var.recreate_flux_extension_epoch
   }
   ```

3. Add `replace_triggered_by` to `azurerm_kubernetes_cluster_extension.flux`:

   ```hcl
   lifecycle {
     replace_triggered_by = [
       terraform_data.flux_extension_recreate_epoch,
     ]
   }
   ```

4. Add the same `replace_triggered_by` trigger to both Flux configuration resources. This is mandatory, not optional:

   - `azurerm_kubernetes_flux_configuration.platform`
   - `azurerm_kubernetes_flux_configuration.backstage`

   This gives Terraform the required destroy/create ordering:

   1. Destroy `backstage-demo` Flux configuration.
   2. Destroy `platform-demo` Flux configuration.
   3. Destroy the `microsoft.flux` extension.
   4. Recreate the `microsoft.flux` extension.
   5. Recreate `platform-demo`.
   6. Recreate `backstage-demo`.

   `replace_triggered_by` on the extension alone is not sufficient because Terraform would not necessarily replace dependent Flux configurations. Microsoft guidance says the Flux configurations must be deleted before the extension.

5. Document the migration variable in the deployment README/runbook:

   - Keep it empty for normal deploys.
   - Set it once, for example to `2026-06-flux-controller-wi`, when migrating from old object-level Flux workload identity keys to controller-level source-controller workload identity.
   - Do not change it again unless another extension reset is required.
   - Do not clear it back to `""`; that is another input change and would trigger another replacement.
   - Do not add `create_before_destroy`; the extension has the fixed name `flux`, so replacement must destroy before create.

Break-glass fallback if Terraform replacement ordering proves unreliable:

1. Add a dedicated operational runbook/workflow step that deletes Flux configurations first:

   ```bash
   az k8s-configuration flux delete \
     -g rg-pe-demo-platform-sec \
     -c aks-pe-demo-sec \
     -t managedClusters \
     -n backstage-demo \
     --yes

   az k8s-configuration flux delete \
     -g rg-pe-demo-platform-sec \
     -c aks-pe-demo-sec \
     -t managedClusters \
     -n platform-demo \
     --yes
   ```

2. Then delete the extension:

   ```bash
   az k8s-extension delete \
     -g rg-pe-demo-platform-sec \
     -c aks-pe-demo-sec \
     -t managedClusters \
     -n flux \
     --yes
   ```

3. Run Terraform apply from `main` so it recreates the extension and Flux configurations from clean IaC state.

This fallback is operationally clear but less self-contained than the Terraform-trigger approach. It should be documented in the same runbook as a break-glass recovery path, not as the default implementation.

### 2. Account for prune-driven workload teardown

Both managed Flux Kustomizations use pruning:

- `platform-demo`: `garbage_collection_enabled = true`
- `backstage-demo`: `garbage_collection_enabled = true`

Deleting Flux configurations while Flux controllers are running can therefore prune in-cluster resources managed by those configurations, including platform controllers and Backstage resources. This is expected during the migration.

Operational impact:

- `demo`: acceptable if the team expects temporary platform/Backstage teardown and verifies self-healing after Terraform recreates Flux.
- `nonprod`: treat as a maintenance-window operation because shared platform add-ons can be temporarily removed and recreated.
- `prod`: do not run without an approved maintenance window, rollback plan, and stakeholder notification.

Before replacement, capture evidence outside source control for rollback/forensics:

```bash
az k8s-extension show \
  -g rg-pe-demo-platform-sec \
  -c aks-pe-demo-sec \
  -t managedClusters \
  -n flux \
  > flux-extension-pre-migration.json

az k8s-configuration flux show \
  -g rg-pe-demo-platform-sec \
  -c aks-pe-demo-sec \
  -t managedClusters \
  -n platform-demo \
  > flux-platform-demo-pre-migration.json

az k8s-configuration flux show \
  -g rg-pe-demo-platform-sec \
  -c aks-pe-demo-sec \
  -t managedClusters \
  -n backstage-demo \
  > flux-backstage-demo-pre-migration.json
```

Keep these files out of git because they may include generated operational metadata or protected settings markers.

### 3. Keep the final desired Flux extension settings simple

The desired extension settings should remain:

```hcl
configuration_settings = {
  "multiTenancy.enforce"                          = "true"
  "kustomize-controller.strict-substitution-mode" = "true"
  "helm-controller.detectDrift"                   = "true"
  "workloadIdentity.enable"                       = "true"
  "workloadIdentity.azureClientId"                = local.flux_source_workload_identity_client_id
  "workloadIdentity.azureTenantId"                = var.tenant_id
}
```

Do not reintroduce:

```text
source-controller.featureGates
sourceController.featureGates
sourceController.featureGates.ObjectLevelWorkloadIdentity
```

The tenant `OCIRepository.spec.serviceAccountName` path was intentionally removed. Tenant chart-source authorization is now enforced by:

- Source-controller workload identity
- `AcrPull` on the platform ACR
- Kyverno allow-list requiring `oci://${platform_acr_login_server}/helm/*`
- Cosign verification in tenant OCIRepository definitions

### 4. Preserve partially applied resources

The failed apply already created resources that are valid in the final design:

- `id-pe-demo-sec-flux-source`
- `AcrPull` for that identity on the platform ACR

Do not sweep these into the Flux extension replacement. They should remain in Terraform state and be preserved after the next successful apply unless a later plan shows an unrelated reason to replace them.

### 5. Required implementation deliverables

The implementation PR should include:

1. Terraform migration wiring:
   - `recreate_flux_extension_epoch` variable.
   - `terraform_data.flux_extension_recreate_epoch`.
   - `replace_triggered_by` on the Flux extension and both Flux configuration resources.
2. Regression guard in `scripts/gitops/validate_stage07_gitops.py`:
   - Add a `require_not_contains` helper.
   - Assert `infrastructure/terraform/platform/gitops.tf` does not contain:
     - `source-controller.featureGates`
     - `sourceController.featureGates`
     - `ObjectLevelWorkloadIdentity`
   - Optionally assert the migration trigger wiring exists.
3. Operational runbook:
   - Add `docs/runbooks/flux-extension-recovery.md`.
   - Include the IaC migration path, break-glass CLI path, expected prune behavior, backup commands, verification commands, and rollback notes.
4. Architecture decision record:
   - Add the next ADR, currently expected to be `docs/adr/0054-flux-controller-workload-identity-migration.md`.
   - Record the decision to use controller-level Flux source identity, reject object-level `OCIRepository.spec.serviceAccountName`, and use a one-time migration epoch for stale extension Helm values.

### 6. Re-run deployment after migration

After implementing the migration path:

1. Run the validation set:

   ```bash
   make lint validate policy-test-kyverno gitops-contracts policy-test-rego
   ```

   Confirm Terraform fmt, TFLint, and Terraform validation pass with the new `terraform_data` and lifecycle wiring.

2. Open/merge a PR.
3. Confirm main workflows pass.
4. Ensure protected platform tfvars still include the migration epoch and current Backstage values:

   ```json
   {
     "backstage_image_digest": "sha256:745120f001948c5e8d679917436b6ccd6c6bb2118cbc241beb15afe8a974f3c5",
     "backstage_catalog_reconciler_image_digest": "sha256:4959f66cf8317b654cfec9d04cc7935fc56c8647e1be84710b7fb571f19c1aad",
     "backstage_chart_digest": "sha256:21e49682ac8ec5676c84b846e2a2e2e2f9f2a9382b9acc7a96e59923b066bd06",
     "enable_gitops": true,
     "enable_backstage": true,
     "enable_techdocs_storage": true,
     "cluster_state_repository_url": "ssh://git@github.com/edinc/platform-cluster-state.git",
     "gitops_repository_provider": "Generic",
     "availability_zones": ["2"],
     "recreate_flux_extension_epoch": "2026-06-flux-controller-wi"
   }
   ```

5. Sync `platform-gitops/` to `edinc/platform-cluster-state`.
6. Run platform plan.
7. Run platform apply.
8. Run a second platform plan with the same epoch value unchanged. It must not propose another Flux extension or Flux configuration replacement.

### 7. Verify successful end-to-end behavior

After successful apply:

1. Verify Flux extension config no longer contains object-level feature-gate keys:

   ```bash
   az k8s-extension show \
     -g rg-pe-demo-platform-sec \
     -c aks-pe-demo-sec \
     -t managedClusters \
     -n flux \
     --query configurationSettings
   ```

2. Verify Flux configurations have current substitutions:

   ```bash
   az k8s-configuration flux show \
     -g rg-pe-demo-platform-sec \
     -c aks-pe-demo-sec \
     -t managedClusters \
     -n platform-demo

   az k8s-configuration flux show \
     -g rg-pe-demo-platform-sec \
     -c aks-pe-demo-sec \
     -t managedClusters \
     -n backstage-demo
   ```

   Expected:

   - `platform-demo` includes `platform_acr_login_server`.
   - `platform-demo` no longer includes `otel_trace_sampling_percentage`.
   - `backstage-demo` includes the new Backstage digests listed above.

3. Verify in-cluster Flux readiness:

   ```bash
   az aks command invoke \
     -g rg-pe-demo-platform-sec \
     -n aks-pe-demo-sec \
     --command "kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A && kubectl get helmreleases.helm.toolkit.fluxcd.io -A"
   ```

   Expected:

   - `platform-demo-cluster-demo`: Ready/True
   - `platform-config`: Ready/True
   - `platform-controllers`: Ready/True
   - `backstage-demo-backstage-demo`: Ready/True
   - `backstage/backstage`: Ready/True

4. Verify Backstage runtime:

   ```bash
   az aks command invoke \
     -g rg-pe-demo-platform-sec \
     -n aks-pe-demo-sec \
     --command "kubectl -n backstage get deploy,pods,ingress,certificate,externalsecret"
   ```

   Expected:

   - Backstage deployment available.
   - Backstage pods running.
   - Backstage ingress present.
   - Certificate ready.
   - ExternalSecrets synced.

5. Run the existing Azure smoke workflow/check from the self-hosted runner network:

   - Dispatch `Backstage CI` from `main` with `run_azure_smoke=true`, or run `scripts/azure/validate_stage09_azure.sh` from an equivalent runner context.

6. Only mark the E2E flow complete when:

   - Backstage URL responds.
   - Backstage can reach AKS/catalog integrations.
   - TechDocs storage check passes.
   - Golden path template flow is usable.

## Acceptance criteria for the implementation

1. Platform Terraform apply succeeds from `main`.
2. The live Flux extension has only the supported controller-level workload identity settings and no stale object-level feature-gate keys.
3. Both Azure Flux configurations are compliant.
4. All Flux Kustomizations and HelmReleases are Ready.
5. Backstage deploys with the newly published image and chart digests.
6. Backstage smoke validation passes from the Azure/self-hosted runner network.
7. The migration path is documented in `docs/runbooks/flux-extension-recovery.md`.
8. ADR `0054` records the source identity and Flux extension migration decision.
9. Stage 07 validation includes a regression guard that fails if any object-level Flux workload identity feature-gate setting is reintroduced.
10. A second platform Terraform plan with the migration epoch unchanged shows no repeat replacement of the Flux extension or Flux configurations.
