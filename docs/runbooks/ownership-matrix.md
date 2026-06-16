# Ownership matrix

Stage: 10 - multi-tenancy, onboarding, and ownership

This matrix is the canonical responsibility document for controlled platform and
workload artifacts. If ownership changes, update this runbook and
[ADR-0043](../adr/0043-ownership-matrix.md) in the same PR.

## RACI

| Artifact | Responsible | Accountable | Consulted | Informed | Notes |
| --- | --- | --- | --- | --- | --- |
| Management groups and ALZ policy | External ALZ/platform foundation owner | External ALZ/platform foundation owner | Platform team, security | App teams | Existing prerequisite; this repo validates assumptions only. |
| Subscription baseline | Platform team | Platform lead | Security, FinOps | App teams | Stage 02 Terraform owns subscription-scoped diagnostics, Defender, budgets, and exports. |
| Hub VNet, Firewall, Private DNS | Platform team | Platform lead | Network team, security | App teams | Stage 03 owns repo-managed connectivity unless an external connectivity subscription owns central zones. |
| Egress allowlist | Platform team | Security owner | Owning app team | FinOps, SRE | Exceptions are time-boxed and reviewed through `request-egress-exception`. |
| Platform AKS cluster | Platform team | Platform lead | SRE, security | App teams | Stage 04/07 own cluster baseline and in-cluster platform add-ons. |
| Backstage portal | Platform team | Platform lead | App teams | All developers | Stage 09 owns hosting, plugins, catalog ingestion, TechDocs, and RBAC policy code. |
| Entra group `pe-app-team-<name>` | Platform team | Owning app team | Security | Backstage users | Created by Stage 10 team onboarding Terraform; membership is managed in Entra. |
| GitHub team `app-team-<name>` | Platform team | Owning app team | Repository owners | App team members | Created by Stage 10; repo permissions are explicit and least-privilege. |
| ACR repo `<team>/*` | Owning app team | Owning app team | Platform team | Security | Vended access only; ACR service remains platform-owned. |
| AKS namespace `<team>-<product>-<environment>` | Owning app team | Owning app team | Platform team, SRE | Security | Vended through Stage 05; RBAC is namespace-scoped and GitOps-first. |
| Backstage Component | Owning app team | Owning app team | Platform team | Consumers | `spec.owner` is mandatory and must point at a synced Entra group/user ref. |
| Azure resources via ASO | Owning app team | Owning app team | Platform team | Security, FinOps | `managedBy: aso`; Flux owns Kubernetes desired state for ASO resources. |
| Azure resources via Terraform vending | Platform team / vending PR | Owning app team | Security, FinOps | SRE | `managedBy: terraform`; state and approvals stay in protected workflows. |
| Cost allocation metadata | Owning app team | FinOps | Platform team | Product leadership | `team`, `product`, `costCenter`, and data classification tags are required at onboarding. |
| Runbooks and TechDocs | Owning artifact team | Owning artifact team | Platform team | Developers | Restricted-tier docs require ownership annotations and reviewer approval. |

## Change control

1. Open a PR for ownership changes.
2. Include affected artifact paths, current owner, requested owner, and approval
   from both current and future accountable roles.
3. Update Backstage catalog `spec.owner`, cost allocation metadata, CODEOWNERS,
   and runbooks in the same PR where applicable.
4. For decommissioning, follow
   [team-decommissioning.md](team-decommissioning.md) before removing ownership
   records.
