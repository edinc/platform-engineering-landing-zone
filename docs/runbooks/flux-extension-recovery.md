# Runbook: Flux extension recovery

Use this runbook when the AKS `microsoft.flux` extension has stale Helm
configuration values that cannot be removed in-place and Terraform cannot update
the extension.

Related decision: [ADR-0054](../adr/0054-flux-controller-workload-identity-migration.md).

## When to use

Use the migration path only when all of these are true:

1. The platform stack owns the AKS Flux extension and Flux configurations.
2. The extension update fails because persisted extension settings conflict with
   the desired controller-level Workload Identity configuration.
3. A normal Terraform apply cannot converge the extension.

Do not use this runbook for ordinary GitOps drift, failed Helm releases, or
tenant workload failures. Fix those in source and let Flux reconcile.

## Impact

The platform and Backstage Flux configurations use pruning. Replacing them can
temporarily remove and recreate resources they manage.

| Environment | Operating model |
| --- | --- |
| `demo` | Acceptable with operator awareness and post-apply validation. |
| `nonprod` | Use a maintenance window because shared add-ons may be temporarily unavailable. |
| `prod` | Requires an approved maintenance window, rollback plan, and stakeholder notification. |

## Evidence capture

Save pre-migration evidence outside the repository:

```bash
capture_dir="$HOME/.copilot/flux-recovery/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$capture_dir"
cd "$capture_dir"

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

Keep these files out of git because they may include operational metadata or
protected-setting markers.

## Preferred IaC migration

The first migration after introducing this runbook uses Terraform's explicit
replacement flags. This is required because Terraform does not trigger
`replace_triggered_by` from a newly created `terraform_data` resource in the same
apply. After this code has been applied once, future resets can use
`recreate_flux_extension_epoch` alone.

1. Confirm the platform variables include the target cluster-state repository,
   current Backstage image/chart digests, and GitOps enablement.
2. Set `recreate_flux_extension_epoch` once to a stable migration token, for
   example:

   ```hcl
   recreate_flux_extension_epoch = "2026-06-flux-controller-wi"
   ```

3. Dispatch **Deploy infrastructure stack** from `main` with:

   | Input | Value |
   | --- | --- |
   | `stack` | `platform` |
   | `action` | `plan` |
   | `environment` | The protected environment for the target profile |
   | `profile` | The target profile |
   | `subscription_id` | The platform subscription ID |
   | `replace_addresses` | See the value below |

   ```text
   azurerm_kubernetes_flux_configuration.backstage[0]
   azurerm_kubernetes_flux_configuration.platform[0]
   azurerm_kubernetes_cluster_extension.flux[0]
   ```

   Include only addresses that exist in the target Terraform state. For profiles
   where Backstage is disabled or was never created, omit
   `azurerm_kubernetes_flux_configuration.backstage[0]`.

   Equivalent local Terraform plan command:

   ```bash
   terraform plan \
     -replace=azurerm_kubernetes_flux_configuration.backstage[0] \
     -replace=azurerm_kubernetes_flux_configuration.platform[0] \
     -replace=azurerm_kubernetes_cluster_extension.flux[0]
   ```

   The plan must replace:

   - `azurerm_kubernetes_flux_configuration.backstage`
   - `azurerm_kubernetes_flux_configuration.platform`
   - `azurerm_kubernetes_cluster_extension.flux`

   Stop if the plan shows the Flux extension as an in-place update instead of a
   replacement; that path can hit the stale Helm value merge failure again.

4. Confirm the ordering destroys Flux configurations before the extension and
   recreates the extension before recreating the configurations.
5. Apply the platform Terraform stack with the same replacement flags:

   Dispatch **Deploy infrastructure stack** again from `main` with
   `action=apply` and the same `replace_addresses` value.

   Equivalent local Terraform apply command:

   ```bash
   terraform apply \
     -replace=azurerm_kubernetes_flux_configuration.backstage[0] \
     -replace=azurerm_kubernetes_flux_configuration.platform[0] \
     -replace=azurerm_kubernetes_cluster_extension.flux[0]
   ```

6. Do not clear the epoch after a successful migration. Clearing or changing it
   is another input change and intentionally triggers another replacement.

Do not set `create_before_destroy`; the AKS extension has the fixed name `flux`
and must be destroyed before it can be recreated.

For later recovery events, when `terraform_data.flux_extension_recreate_epoch`
already exists in state, changing `recreate_flux_extension_epoch` is sufficient
to trigger the same replacements. The plan must still show replacements before
you apply.

## Backstage chart labels

The Backstage chart disables chart-owned standard metadata labels by default
because the AKS Flux extension post-renderer injects `team`, `costCenter`, and
`dataClassification` onto managed objects. Duplicating those keys in rendered
Helm YAML can fail the Helm install. The Backstage pod template still carries
`app`, `team`, `costCenter`, and `dataClassification` through `podLabels` so the
Kyverno `require-standard-labels` policy admits the pods.

## Break-glass CLI fallback

Use this only if Terraform replacement ordering cannot complete.

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

az k8s-extension delete \
  -g rg-pe-demo-platform-sec \
  -c aks-pe-demo-sec \
  -t managedClusters \
  -n flux \
  --yes
```

Then run platform Terraform apply from the protected branch so the extension and
Flux configurations are recreated from IaC.

## Verification

Verify the extension no longer contains object-level Workload Identity feature
gate settings:

```bash
az k8s-extension show \
  -g rg-pe-demo-platform-sec \
  -c aks-pe-demo-sec \
  -t managedClusters \
  -n flux \
  --query configurationSettings
```

Expected keys:

- `multiTenancy.enforce`
- `kustomize-controller.strict-substitution-mode`
- `helm-controller.detectDrift`
- `workloadIdentity.enable`
- `workloadIdentity.azureClientId`
- `workloadIdentity.azureTenantId`

Unexpected keys:

- `source-controller.featureGates`
- `sourceController.featureGates`
- `sourceController.featureGates.ObjectLevelWorkloadIdentity`

Verify the Flux configurations have current substitutions:

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
- `platform-demo` includes `github_owner`.
- `platform-demo` does not include removed one-off substitutions.
- `backstage-demo` includes the current Backstage image, reconciler image, and
  chart digests.

Verify in-cluster readiness:

```bash
az aks command invoke \
  -g rg-pe-demo-platform-sec \
  -n aks-pe-demo-sec \
  --command "kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A && kubectl get helmreleases.helm.toolkit.fluxcd.io -A"
```

Expected:

- `platform-demo-cluster-demo`: Ready `True`
- `platform-config`: Ready `True`
- `platform-controllers`: Ready `True`
- `backstage-demo-backstage-demo`: Ready `True`
- `backstage/backstage`: Ready `True`

Verify Backstage:

```bash
az aks command invoke \
  -g rg-pe-demo-platform-sec \
  -n aks-pe-demo-sec \
  --command "kubectl -n backstage get deploy,pods,svc,ingress,certificate,externalsecret"
```

Expected:

- Backstage deployment is available.
- Backstage pods are running.
- Backstage service and ingress exist.
- Certificate is ready.
- ExternalSecrets are synced.

Run the developer-portal Azure smoke check from the self-hosted runner network:

```bash
bash scripts/azure/validate_backstage_azure.sh
```

## Rollback

Prefer forward recovery by reverting the source commit or Terraform variables and
applying again. If the extension cannot reconcile:

1. Re-run the break-glass delete sequence.
2. Restore the last known-good platform Terraform variables.
3. Apply the platform stack.
4. Re-sync `platform-gitops/` into `platform-cluster-state`.
5. Confirm Flux and Backstage readiness with the verification commands above.
