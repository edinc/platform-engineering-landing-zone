# ADR-0026: AVM module pinning, upgrade cadence, and the ALZ composition choice

- Status: accepted
- Date: 2026-06-09
- Stage: Stage 02 - ALZ baseline and compliance baseline

## Context

The Stage 02 technology table names `Azure/caf-enterprise-scale` for management
groups plus policy, and Azure Verified Modules (`Azure/avm-res-*`,
`Azure/avm-ptn-*`) for resources. Two constraints from the platform CI and
operating model force a decision before adopting any of them:

1. **Credential-free CI.** Every `*.tf` directory must pass
   `terraform init -backend=false && terraform validate` plus `tflint` and
   `checkov` with no Azure credentials (ADR-0048 runner model, Stage 00 gates).
   Modules that require provider configuration, data sources, or a real ARM
   connection at `init`/`validate` time cannot satisfy this.
2. **Auditable, minimal guardrails.** Stage 02 needs a small, explicit set of
   initiatives with effects we control precisely (audit-first, a single `Deny`),
   not a large opinionated policy surface we then have to carve exceptions into.

`Azure/caf-enterprise-scale` is a large, archetype-driven module whose policy
surface and resource graph are heavyweight for an MVP and awkward to assert under
credential-free validation. `Azure/avm-ptn-alz` (the AVM pattern that replaces it)
was not GA-stable enough to pin with confidence at the time of consumption.

## Decision

**Build the Stage 02 ALZ baseline as a native `azurerm` composition under
`infrastructure/terraform/alz/`, not from `Azure/caf-enterprise-scale` or
`Azure/avm-ptn-alz`. Use Azure Verified Modules for resource building blocks in
later stages, always pinned to a GA version. Record the AVM dependency audit
here.**

1. **ALZ composition.** Management groups, custom initiatives, assignments,
   Defender plans, the central Log Analytics workspace, budgets, and cost exports
   are authored directly with `azurerm` resources. This keeps the stack small,
   credential-free-validatable, and precisely controllable, at the cost of owning
   the MG/policy wiring ourselves.

2. **AVM usage policy.** When a stage adopts an AVM module it MUST:
   - pin an exact GA version in that stack's `versions.tf`/module block (no
     floating ranges, no pre-release unless an ADR justifies it);
   - validate credential-free in CI;
   - be recorded in the audit table below.

3. **Upgrade cadence.** AVM and provider upgrades land as dedicated, reviewed PRs
   (not auto-merged), at most monthly unless a security fix requires sooner. Each
   upgrade re-runs the full validate/lint/policy gates and a `plan` in `demo`.

4. **Provider pinning.** `azurerm ~> 4.14`, `terraform >= 1.9.0, < 2.0.0`, mirrored
   from the `_bootstrap` stack for consistency.

### AVM / ALZ module audit (Stage 02)

| Module | Version | GA? | Decision |
|--------|---------|-----|----------|
| `Azure/caf-enterprise-scale` | n/a | GA | **Not adopted** - heavyweight policy/resource surface, awkward under credential-free `validate`; native composition chosen instead. |
| `Azure/avm-ptn-alz` (ALZ pattern) | n/a | Not GA-stable at consumption | **Not adopted** - revisit when GA and pinnable; would replace the native composition if it validates credential-free. |
| `Azure/avm-res-*` (resource modules) | n/a | Mixed | **Deferred to later stages** - adopt per resource when GA; pin and audit at that time. |

This table is updated as AVM modules are adopted in later stages.

## Consequences

- The ALZ stack passes the same credential-free gates as `_bootstrap`, so Stage
  02 lands without weakening CI.
- We own the MG hierarchy and policy wiring; there is no upstream module doing it
  for us, which is more code but far less hidden behaviour and a smaller blast
  radius.
- Migrating to `Azure/avm-ptn-alz` later is possible but would be a reviewed
  re-platforming, since state and resource addresses differ.
- The deviation from the stage technology table is intentional and recorded here;
  the stage file's `caf-enterprise-scale` row should be read together with this
  ADR.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| `Azure/caf-enterprise-scale` as written in the stage table | Large policy/resource surface, heavier than an MVP needs, and harder to assert under credential-free `terraform validate`. |
| `Azure/avm-ptn-alz` now | Not GA-stable enough to pin confidently at consumption time; revisit when GA. |
| Hand-rolled modules under `_modules/` for MG + policy now | Premature abstraction; the native composition in one stack is clearer until a second consumer exists. |

## References

- [`plan/stages/stage-02-alz-baseline.md`](../../plan/stages/stage-02-alz-baseline.md)
- [`infrastructure/terraform/alz/`](../../infrastructure/terraform/alz/)
- [ADR-0001: Primary IaC](0001-iac.md)
- [ADR-0048: Runner connectivity model](0048-runner-connectivity.md)
