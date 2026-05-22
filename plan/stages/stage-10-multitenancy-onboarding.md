# Stage 10 — Multi-tenancy, onboarding, and ownership

## Goal

Make the platform safely consumable by multiple teams: codify the team /
product / namespace / cost-center entity, the onboarding flow, the
ownership matrix, and the developer inner-loop.

## Scope (in)

### Team / product onboarding

- A single **Backstage software template** `onboard-team` (the meta-template
  that precedes all v1 service golden paths):
  - Inputs: team name, product name, cost center, on-call rotation ID,
    GitHub team, data classification.
  - Outputs:
    - Entra ID group `pe-app-team-<name>` (via Terraform `azuread`).
    - GitHub team `app-team-<name>` with default repo permissions.
    - Backstage `Group` + `User` entities reconciled from Entra.
    - A Vending request for one AKS namespace per environment
      (Stage 05 workflow).
    - Cost-allocation entries.
- **Renaming/decommissioning** documented runbooks.

### Ownership matrix

`docs/runbooks/ownership-matrix.md` lists every controlled artifact with
responsible / accountable / consulted / informed roles. Excerpt:

| Artifact | Owner | Notes |
|----------|-------|-------|
| Management groups, ALZ policy | Platform team | Stage 02 |
| Hub VNet, Firewall, Private DNS | Platform team | Stage 03 |
| AKS cluster | Platform team | Stage 04 |
| ACR repo `<team>/*` | Owning app team | Vended |
| AKS namespace `<team>-<env>` | Owning app team | Vended; RBAC scoped |
| Backstage Component | Owning app team | `spec.owner` mandatory |
| Azure resources via ASO | Owning app team | `managedBy: aso` |
| Azure resources via TF | Platform / vending PR | `managedBy: terraform` |

### Backstage tenancy + RBAC hardening

- Catalog entity rules: every `Component` *must* have `spec.owner` referencing
  an Entra group. CI rejects PRs missing it.
- Scaffolder authorization: only the team's owning group + platform admins
  can execute team-scoped templates.
- TechDocs visibility scoped by ownership annotations (read-mostly default;
  restricted-tier docs gated).

### Developer inner-loop

- **Devcontainers** for all golden-path templates (.devcontainer/ generated).
- **Tilt** is the **primary** inner-loop tool — fast multi-service reload,
  active upstream, broad community.
- **Bridge to Kubernetes** is documented as a **secondary** option for
  single-service VS Code workflows, with a noted caveat that Microsoft
  investment has slowed; the platform does not depend on it as the only
  path.
- **Telepresence** considered and rejected (operational complexity).
- `pectl` (platform CLI, Stage 13) is roadmap-only here; for now developers
  use `kubectl`, `gh`, `az`, `backstage scaffolder` URLs.

### Egress & policy exception workflow (consumer-facing)

- Backstage form-based template `request-egress-exception` opens a PR against
  `policies/azure/firewall/allowlist.json` and the cluster-state
  `clusters/_base/network/` directory (Cilium FQDN policies for the demo
  profile).
- Time-boxed (90 day) exceptions with expiry alerts.

### Cost showback

- Stage-08 cost allocator (Function App) publishes per-team Grafana
  dashboards.
- Backstage Cost Insights tab filters by Entra group → team `costCenter`.

## Scope (out)

- The v1 golden paths themselves (Stage 11).
- Visual studio code extension (Stage 13).

## Deliverables

- `templates/onboard-team/` — meta-template.
- `templates/request-egress-exception/` — exception template.
- `policies/backstage/ownership-required.ts` — CI rule.
- `docs/runbooks/ownership-matrix.md`.
- `docs/runbooks/team-onboarding.md`.
- `docs/runbooks/team-decommissioning.md` — counterpart for sunsetting a
  team: revoke Entra group, archive GH team, decommission namespaces,
  reassign Backstage Components or mark `deprecated`, terminate vended
  subscriptions.
- `docs/adr/0018-inner-loop.md` — devcontainers + Tilt (primary) /
  Bridge to Kubernetes (secondary).
- **Onboarding-template idempotency contract**: each step (Entra group,
  GH team, Backstage entity, vending PR) is independently re-runnable;
  partial-failure recovery is documented in `team-onboarding.md`.
- **Onboarding smoke test** (`scripts/test/onboarding-smoke.sh`) that the
  Stage 11 golden-path templates depend on as a pre-gate.

## Dependencies

- Stage 03 (Entra groups + PIM substrate), Stage 05 (vending), Stage 09
  (Backstage), Stage 06 (CI for ownership rule).

## Decisions / ADRs

- **ADR-0018** Inner-loop = devcontainers + **Tilt** (primary) / Bridge
  to Kubernetes (secondary).
- **ADR-0043** Ownership matrix is the canonical responsibility document.

## Technologies

| Concern | Choice |
|---------|--------|
| Onboarding | Backstage scaffolder calling Stage-05 vending workflows |
| RBAC | Entra ID groups + Backstage Permission Framework |
| Inner loop | Devcontainers + Tilt (Bridge to Kubernetes as secondary) |
| Cost showback | Grafana per-team dashboards + Backstage Cost Insights |

## Acceptance criteria

1. A new team can be onboarded end-to-end in < 1 hour from `onboard-team`
   template submission to a working namespace in dev + nonprod + prod.
2. Catalog entities without `spec.owner` are rejected at PR time.
3. A developer can `code` into a sample template's devcontainer, run **Tilt**
   against the dev cluster, and hit a service within < 15 min on a fresh
   laptop.
4. An egress exception request creates an auditable, time-bounded firewall
   rule and NetworkPolicy that auto-expires.
5. Cost showback dashboard updates within 24h of resource consumption.
6. Onboarding smoke test passes; partial-failure recovery procedure
   reliably re-converges a half-onboarded team without manual portal
   intervention.
7. The team-decommissioning runbook is dry-run-validated end to end.

## Risks

- **Onboarding flow brittleness** (Entra + GitHub + Vending + Backstage in
  one transaction) → idempotent template steps + clear recovery runbook
  + the smoke test above.
- **Bridge to Kubernetes regional / feature gaps + reduced upstream
  investment** → Tilt is primary; Bridge documented as secondary only.
- **Egress exception sprawl** → quarterly automated review + auto-expire.
