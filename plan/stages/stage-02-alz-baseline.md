# Stage 02 — Azure Landing Zone baseline & compliance baseline

## Goal

Deploy the ALZ management-group hierarchy, attach policy initiatives that
implement the chosen compliance baseline, and centralise logging, Defender,
budgets, and tags.

## Scope (in)

- **Management-group hierarchy** (ALZ):
  - Tenant Root → `alz` → {`platform`, `landingzones`, `sandbox`, `decommissioned`}.
  - `platform` → {`management`, `connectivity`, `identity`}.
  - `landingzones` → {`corp`, `online`}.
- **Subscriptions** placed under the right MGs:
  - `management` (central LA + Defender + cost exports).
  - `connectivity` (hub VNet, Firewall, Private DNS).
  - `identity` (automation accounts; Entra Domain Services deferred to
    Stage 13 unless required by a concrete workload).
  - One `landingzones/corp` workload subscription as the first test target.
- **Policy initiatives**:
  - ALZ "audit" / "deploy" / "regulated" sets where relevant.
  - **CIS Microsoft Azure Foundations Benchmark v2** built-in initiative
    assigned at `alz`.
  - Custom initiative `tag-baseline`: require `env`, `owner`, `costCenter`,
    `product`, `dataClassification`, `confidentiality`, `managedBy`, `repo`.
  - Custom initiative `private-link-required` for KV, Storage, ACR, PG.
  - Custom initiative `aks-baseline` (RBAC, Workload Identity, OS upgrade
    channel, image cleaner, Defender profile, Azure Monitor agent).
    **Important**: this initiative **does not** enable the
    `Microsoft.PolicyInsights/AKS` (Gatekeeper) add-on — it is explicitly
    omitted to avoid conflict with Kyverno as the single in-cluster
    admission engine (see ADR-0036 and Stage 07).
- **Central Log Analytics workspace** (in `management` subscription).
- **Diagnostic settings policy** to ship platform-wide logs to LA.
- **Defender for Cloud** plans enabled at the `platform` MG: Servers P2,
  Containers, Key Vault, Storage, DB, Resource Manager, APIs.
- **Cost Management**: budgets per subscription; **exports to an ADLS Gen2
  account** in `management` (Terraform-provisioned in this stage —
  `infrastructure/terraform/alz/cost-exports.tf` — with a PE, lifecycle
  rules, and a service principal grant for Cost Management's
  `Microsoft.CostManagement` writer).
- **AVM module maturity audit** documented as `docs/adr/0026-avm-modules.md`,
  listing each AVM module the platform depends on, version, and whether GA.
- **Brownfield onramp** documented: discovery script + audit-only policy
  rollout mode for an existing tenant.

## Scope (out)

- Networking (Stage 03).
- Compute (Stage 04+).
- Sentinel (deferred to Stage 12 trigger).

## Deliverables

- `infrastructure/terraform/alz/` — composition based on the current ALZ
  Terraform pattern (`Azure/avm-ptn-alz` if GA at the time of consumption;
  otherwise pinned `Azure/caf-enterprise-scale`) + custom initiatives.
  The chosen module is recorded with version in ADR-0026.
- `infrastructure/terraform/alz/cost-exports.tf` — ADLS Gen2 storage account
  + container + Cost Management export schedule.
- `policies/azure/initiatives/` — custom initiative definitions in JSON/Bicep.
- `docs/runbooks/policy-exception.md` — exception workflow (request → approve →
  time-bound → audit).
- `docs/adr/0011-compliance-baseline.md` — CIS Foundations v2 + ALZ regulated.
- `docs/adr/0026-avm-modules.md` — module audit + ALZ-module choice.
- `docs/runbooks/brownfield-onboarding.md` — audit-only onramp.

## Dependencies

- Stage 01 (state, OIDC, KV).

## Decisions / ADRs

- **ADR-0011** Compliance baseline = CIS Foundations v2 + ALZ regulated.
- **ADR-0026** AVM module pinning + upgrade cadence.
- **ADR-0027** Policy exception workflow & approver matrix.
- **ADR-0028** Subscription topology (initial: per-environment subscriptions
  for `nonprod` and `prod` in landingzones/corp; `demo` as a single sub).

## Technologies

| Concern | Choice |
|---------|--------|
| MG + policy composition | `Azure/caf-enterprise-scale` Terraform module |
| Resource modules | Azure Verified Modules (`Azure/avm-res-*` Terraform) |
| Compliance baseline | CIS Azure Foundations Benchmark v2 (built-in initiative) |
| Logging | Central Log Analytics workspace |
| Security posture | Microsoft Defender for Cloud plans |
| Cost | Azure Cost Management exports → ADLS Gen2 |

## Acceptance criteria

1. Management groups + initial subscriptions exist as designed.
2. CIS Foundations + ALZ initiatives are assigned with the chosen
   effects (mostly `Audit` + `DeployIfNotExists`, with **the explicit
   exception** of the `tag-baseline` initiative's `Deny`-on-missing-tag
   effect — broad denies on other initiatives wait for a tenant-wide
   grace period).
3. Tag policy denies new resources missing mandatory tags (the only
   pre-approved `Deny` at this stage).
4. Defender for Cloud Secure Score appears in `management`.
5. Cost Management exports land in the ADLS Gen2 account on the daily
   schedule.
6. A representative Terraform `plan` in `demo` is **policy-compliant** end to
   end.
7. Brownfield runbook is dry-run-validated against an existing test
   subscription.
8. `aks-baseline` initiative **does not** install the AKS Policy add-on
   (verified by inspecting the initiative parameters).

## Risks

- **Policy noise on existing resources** → start with `Audit`; switch effects
  to `Deny` only after exemption inventory is drained.
- **AVM churn** → pinned module versions in `versions.tf`; periodic upgrade
  PRs reviewed.
- **MG move blast radius** → moves are documented and reviewed by platform
  + security before merge.
