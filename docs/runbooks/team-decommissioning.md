# Team decommissioning runbook

Capability: multi-tenancy & onboarding

Use this runbook to sunset an application team without orphaning access,
catalog ownership, cost data, or vended infrastructure.

## Dry run

1. Locate the `TeamOnboardingRequest`, team Terraform state key, namespace
   vending states, and cluster-state tenant paths.
2. List Backstage entities where `spec.owner` references the team group.
3. List repositories where `app-team-<name>` has access.
4. List vended namespaces, workload identities, ACR repository paths, Key Vault
   secret scopes, and ASO-owned Azure resources.
5. Confirm FinOps no longer expects active showback for the cost center/product.

The dry run is complete only when every artifact has an owner-preserving action:
reassign, archive, or destroy.

## Decommission

| Artifact | Action |
| --- | --- |
| Backstage Components | Reassign `spec.owner` or mark `lifecycle: deprecated` with a replacement owner. |
| GitHub repositories | Remove the GitHub team only after repository CODEOWNERS and branch protection no longer reference it. |
| AKS namespaces | Remove tenant workloads from cluster-state, merge the pruning PR, then destroy the matching namespace vending state. |
| Workload identities and role assignments | Destroy through the namespace vending Terraform state after Flux prunes workloads. |
| ACR repositories | Archive image evidence required by retention policy, then remove team-specific permissions. |
| Entra group | Remove members, archive evidence, then destroy/import-remove through team onboarding Terraform. |
| Cost allocation | Mark the team inactive after the final Cost Management export is processed. |

## Validation

1. `scripts/test/onboarding-smoke.sh` still passes for a sample active team.
2. Backstage catalog has no active Component owned by the retired group.
3. Azure role assignments for the retired group return no active workload scopes.
4. Namespace paths under `platform-cluster-state/tenants/<team>/` are removed or
   retained only as archived evidence.
5. Cost dashboards show no new spend after the agreed sunset date.

Never delete the team Terraform state before confirming there are no remaining
role assignments or repository permissions owned by that state.
