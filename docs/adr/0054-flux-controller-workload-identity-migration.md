# ADR-0054: Flux controller Workload Identity migration

- Status: accepted
- Date: 2026-06-22
- Capability: GitOps platform

## Context

The platform installs Flux through the Microsoft-managed AKS `microsoft.flux`
extension. Earlier experiments used object-level Workload Identity settings for
Flux source objects. The current platform design uses a controller-level source
identity instead:

- The Flux source-controller runs with a managed identity.
- That identity receives `AcrPull` on the platform ACR.
- Tenant chart sources are constrained by Kyverno to
  `oci://${platform_acr_login_server}/helm/*`.
- Source identity and signed artifact verification enforce supply-chain access.

Some live Flux extension instances can retain old object-level Helm settings
alongside the controller-level settings. Azure extension updates then fail while
merging stale scalar and map-shaped Helm `--set` keys.

## Decision

Use controller-level Flux source Workload Identity and do not configure
object-level `OCIRepository.spec.serviceAccountName` authentication for platform
or tenant chart sources.

The platform Terraform stack owns a one-time migration trigger:

```hcl
recreate_flux_extension_epoch = "2026-06-flux-controller-wi"
```

Changing this value intentionally replaces the Flux resources after the trigger
resource already exists in Terraform state:

1. The Backstage Flux configuration.
2. The platform Flux configuration.
3. The AKS `microsoft.flux` extension.

The first migration after introducing the trigger must use explicit Terraform
replacement flags for those same three resources because `replace_triggered_by`
does not fire from a newly created `terraform_data` resource in the same apply.
After the trigger exists in state, changing the epoch can drive later resets. In
both cases, the plan must show replacement, not in-place update.

The replacement path is wired to both Flux configurations and the extension so
Terraform deletes Flux configurations before deleting the extension, then
recreates the extension before recreating the configurations. Keep the epoch
unchanged after a successful migration; clearing or changing it triggers another
replacement once the trigger is in state.

The desired extension settings remain limited to:

- `multiTenancy.enforce`
- `kustomize-controller.strict-substitution-mode`
- `helm-controller.detectDrift`
- `workloadIdentity.enable`
- `workloadIdentity.azureClientId`
- `workloadIdentity.azureTenantId`

Do not reintroduce:

- `source-controller.featureGates`
- `sourceController.featureGates`
- `sourceController.featureGates.ObjectLevelWorkloadIdentity`
- `ObjectLevelWorkloadIdentity`

## Consequences

- Terraform has a controlled, auditable path to reset stale extension state.
- The platform avoids per-object source identity complexity while preserving
  private ACR access and tenant source restrictions.
- Initial rollout requires explicit Terraform `-replace` flags; later resets can
  use an epoch change once the trigger resource is in state.
- Replacement can temporarily prune platform and Backstage resources because the
  managed Flux configurations use pruning. Use maintenance windows for nonprod
  and prod.
- Operators need to keep the migration epoch stable after use to avoid repeated
  replacements.

## Alternatives considered

| Alternative | Reason not chosen |
| --- | --- |
| Keep object-level Workload Identity | It reintroduces extension Helm value conflicts and creates per-source identity complexity. |
| Manually delete the extension from the portal or CLI as the default path | It is not auditable through IaC and risks deleting the extension before Flux configurations. |
| Set only `replace_triggered_by` on the extension | Terraform would not necessarily replace the dependent Flux configurations first, contrary to Microsoft guidance. |
| Disable Flux extension drift detection or multi-tenancy | Weakens the GitOps platform security posture and tenant isolation model. |

## References

- [Flux extension recovery runbook](../runbooks/flux-extension-recovery.md)
- [GitOps platform](../how-it-works/gitops.md)
- [Microsoft Learn: GitOps with Flux v2](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2)
- [Microsoft Learn: Flux cluster extension](https://learn.microsoft.com/azure/azure-arc/kubernetes/conceptual-gitops-flux2#flux-cluster-extension)
- [Microsoft Learn: Azure Arc Kubernetes extensions troubleshooting](https://learn.microsoft.com/azure/azure-arc/kubernetes/extensions-troubleshooting)
