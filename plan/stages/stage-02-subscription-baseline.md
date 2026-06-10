# Stage 02 — Subscription baseline & compliance alignment

## Goal

Onboard and harden existing Azure subscriptions for platform/workload use while
assuming the organization's Azure Landing Zone (management groups, tenant-wide
policy, central shared services, and subscription placement) already exists.

This stage narrows the repo's responsibility from "build an ALZ" to "make a
subscription ready to participate in an existing ALZ-backed platform."

## Scope (in)

- **Subscription-scoped baseline Terraform**:
  - target one existing subscription per stack instance;
  - configure Microsoft Defender for Cloud subscription pricing;
  - optionally route subscription Activity Logs to an existing central Log
    Analytics workspace;
  - optionally create a monthly subscription budget;
  - optionally configure daily Cost Management exports to an existing ALZ-owned
    storage container.
- **Existing ALZ inputs** documented as prerequisites:
  - subscription already exists and is placed in the correct management group;
  - CIS/regulated policy assignments already exist at the tenant/MG layer;
  - central Log Analytics workspace and cost-export storage are supplied as
    resource IDs when this stack needs them.
- **Policy pack retained as reference/optional source of truth**:
  - custom `tag-baseline`, `private-link-required`, and `aks-baseline`
    initiatives remain under `policies/azure/initiatives/`;
  - CI validates them so an ALZ administrator can adopt them, but the Stage 02
    Terraform stack no longer deploys tenant/MG-scoped policy definitions or
    assignments.
- **Mandatory tag taxonomy** retained and validated through Rego and Azure Policy
  initiative checks.
- **Subscription readiness discovery**:
  - read-only script to inspect the target subscription's context, inherited
    policy assignments, Defender pricing, Activity Log diagnostic settings, and
    mandatory-tag gaps.
- **Policy exception workflow** for scoped, time-bound exceptions when inherited
  ALZ policies report non-compliance.
- **AVM/module posture** documented: no ALZ pattern module is used in this stage;
  AVM adoption is deferred to resource-specific later stages.

## Scope (out)

- Creating or changing management-group hierarchy.
- Moving subscriptions between management groups.
- Creating or assigning tenant/MG-scoped Azure Policy.
- Creating central ALZ services such as Log Analytics workspaces, cost-export
  storage accounts, hub networks, Private DNS, or Firewall.
- Networking (Stage 03).
- Compute/platform services (Stage 04+).
- Sentinel (deferred to Stage 12 trigger).

## Deliverables

- `infrastructure/terraform/subscription-baseline/` — subscription-scoped
  Terraform composition.
- `policies/azure/initiatives/` — optional/reference Azure Policy initiative
  definitions validated in CI.
- `scripts/subscription/readiness-discovery.sh` — read-only subscription
  readiness and brownfield discovery script.
- `docs/runbooks/subscription-onboarding.md` — existing-subscription onboarding
  runbook.
- `docs/runbooks/policy-exception.md` — exception workflow (request -> approve
  -> time-bound -> audit).
- `docs/adr/0011-compliance-baseline.md` — compliance baseline expectation when
  an external ALZ owns policy assignments.
- `docs/adr/0026-avm-modules.md` — module audit + decision not to use ALZ
  pattern modules in this subscription-scoped stage.
- `docs/adr/0028-subscription-topology.md` — topology boundary: existing ALZ
  owns subscription placement; this repo baselines subscriptions after placement.

## Dependencies

- Stage 01 (state, OIDC, Key Vault).
- Existing organizational ALZ with appropriate management groups and policy
  assignments.
- Existing shared observability/cost destinations when diagnostics or cost export
  features are enabled.

## Decisions / ADRs

- **ADR-0011** Compliance baseline = inherited ALZ/CIS policy plus
  subscription-scoped hardening by this repo.
- **ADR-0026** AVM module pinning + explicit non-adoption of ALZ pattern modules
  for Stage 02.
- **ADR-0027** Policy exception workflow & approver matrix.
- **ADR-0028** Subscription topology and ownership boundary.

## Technologies

| Concern | Choice |
|---------|--------|
| Subscription baseline | Native `azurerm` Terraform resources |
| Existing ALZ policy | Consumed as an external prerequisite |
| Optional policy pack | JSON Azure Policy initiatives validated in CI |
| Diagnostics | Subscription Activity Log diagnostic setting -> existing Log Analytics |
| Security posture | Microsoft Defender for Cloud subscription pricing |
| Cost | Budget + optional Cost Management export -> existing ALZ storage container |

## Acceptance criteria

1. The Stage 02 Terraform stack targets an existing subscription and does not
   create management groups, move subscriptions, or assign MG-scoped policy.
2. Existing ALZ/CIS policy ownership is documented as an external prerequisite,
   with optional/reference policy initiatives retained and validated in CI.
3. Mandatory tag expectations remain enforceable: Rego checks the Terraform plan
   shape, and `policy-test-azure` validates the optional tag initiative covers
   resources and resource groups.
4. Defender for Cloud plan tiers can be configured for the target subscription.
5. Cost Management exports can be configured to an existing ADLS Gen2 container
   on a daily schedule.
6. A representative Terraform `plan` in `demo` is policy-compliant end to end.
7. Subscription readiness runbook is dry-run-validated against an existing test
   subscription.
8. `aks-baseline` initiative still does **not** install the AKS Policy add-on
   (validated by the Azure Policy guard), even though this stack no longer
   assigns it.

## Risks

- **Hidden ALZ assumptions** -> readiness discovery lists inherited assignments
  and required shared-service IDs before this stack is applied.
- **Policy drift outside this repo** -> optional/reference policy pack remains
  validated here, but the ALZ owner is responsible for assignment and effect
  changes.
- **Missing shared destinations** -> Terraform preconditions fail when diagnostics
  are enabled without a workspace, or budget is enabled without contacts.
- **Subscription ownership ambiguity** -> ADR-0028 and the onboarding runbook
  make placement/moves an external ALZ-team responsibility.
