# Stage 01 — Bootstrap & secret zero

> "Turtles all the way down" stage. Solves the chicken-and-egg of how the first
> Terraform state, the first OIDC federation, and the first Key Vault come into
> existence.

## Goal

Create the *minimum* trust chain that lets every subsequent stage run from
GitHub Actions with no long-lived secrets, against Terraform state stored
durably in Azure, with a documented break-glass path.

## Scope (in)

- **Bootstrap subscription** identification (existing or newly created, owned by
  a tenant Global Admin or via Subscription Vending).
- **Terraform remote state** infrastructure:
  - Resource group `rg-pe-tfstate-<region>`.
  - Storage account (RA-GRS, blob lease lock, soft-delete + versioning, **CMK**
    via Key Vault).
  - **Two-phase access posture**:
    - **Phase 1 (this stage)** — public endpoints **with IP allowlist**: a
      standing list of break-glass operator IPs that Terraform owns and
      drift-detects, plus the GitHub-hosted runner's egress IP added
      just-in-time by the bootstrap workflow for the duration of a run and
      removed afterward (ADR-0048). VNets do not yet exist (created in
      Stage 03), so Private Endpoints cannot be enabled yet.
    - **Phase 2 (retrofit during Stage 03)** — replace the IP allowlist
      with **Private Endpoints** for the state account and seed KV; public
      access disabled; runner access via a self-hosted runner in the hub
      or via Azure DevOps / Microsoft-hosted runners with VNet integration
      (ADR-0048).
  - Containers per stage: `bootstrap`, `alz` (legacy, retained to prevent
    accidental state deletion), `subscription-baseline`,
    `connectivity`, `identity`, `platform`, `vending`, `cicd`, `gitops`,
    `observability`, `backstage`, `onboarding`, `golden-paths`,
    `disaster-recovery`, `envs-demo`, `envs-nonprod`, `envs-prod`.
- **Seed Key Vault** `kv-pe-boot-<region>-<suffix>` for bootstrap-time secrets (HSM
  tier optional). Purge protection on. Phase-1 IP-firewalled; PE retrofit at
  Stage 03 (same two-phase model as state).
- **GitHub ↔ Azure OIDC federation**:
  - One Entra ID *application registration* per stage (least-privilege scopes).
  - Federated credential subject scoped to the GitHub repo + **Environment**
    (`repo:<owner>/<repo>:environment:<env>`); branch gating is enforced by the
    Environment's deployment-branch policy, not a branch-scoped subject
    (ADR-0025 / ADR-0023). Environments are provisioned in Stage 00.
  - Workflow `id-token: write` permission documented.
  - Permission matrix (Graph perms required, app-registration ownership,
    federated-credential subjects per stage) documented in
    `docs/adr/0025-oidc-federation.md`.
- **Break-glass accounts**: **two** Entra cloud-only accounts (primary +
  spare) with MFA + sealed paper credential in geographically-separated
  safes, PIM-eligible owner role at tenant root, alerting on activation
  (Azure Monitor in this stage; Defender for Cloud + Sentinel added in
  Stage 02 / Stage 13 trigger).
- **DNS prerequisites**: confirm parent zone registrar credentials are out of
  band; document delegation steps.
- **Sigstore egress note** — `cosign` keyless will need `rekor.sigstore.dev`,
  `fulcio.sigstore.dev`, `tuf.sigstore.dev` reachable from runners. Stage 03
  hub Firewall allowlist must include these (cross-reference).
- **Bootstrap automation** — a documented path:
  1. `make bootstrap-init` — *one-off* `az login` + `az cli` script run locally
     by a human Global Admin to create the storage account, KV, and OIDC app
     reg. This step is the **only** sanctioned use of the Azure CLI in the
     platform (ADR-0001 exception); documented explicitly.
  2. `make bootstrap-import` — *one-off, local* `terraform import` that adopts
     the four step-1 resources (state resource group, storage account,
     bootstrap container, seed Key Vault) into Terraform state so the first
     apply reconciles them **in place** rather than re-creating them
     (brownfield-safe; the script validates immutable properties before
     handoff). That first apply then also creates the remaining bootstrap
     resources (CMK, UAMI, per-stage state containers, firewall baseline,
     monitoring, role assignments); subsequent applies are drift-only.
  3. The **bootstrap workflow** (`.github/workflows/bootstrap.yml`,
     `action = apply`) — Terraform run *from GitHub Actions via OIDC* against
     the freshly-minted state account, idempotently re-applying its own backing
     infra (proving the loop closes). `make bootstrap-apply` runs the same apply
     **locally** as a break-glass equivalent.

## Scope (out)

- Subscription baseline and inherited ALZ policy alignment (Stage 02);
  networking (Stage 03).
- AKS or any workload infra (Stage 04+).

## Deliverables

- `infrastructure/terraform/_bootstrap/`
  - `main.tf` (RG, seed KV, CMK, UAMI), `state.tf` (state storage account +
    per-stage containers), `monitoring.tf` (break-glass alerting),
    `variables.tf`, `outputs.tf`. Entra app registrations and federated
    credentials are created by `bootstrap-init.sh`, **not** Terraform (ADR-0025).
- `scripts/bootstrap/bootstrap-init.sh` — the one-off pre-Terraform script.
- `docs/runbooks/bootstrap.md` — step-by-step "from existing subscription to
  GH-Actions applying Terraform".
- `.github/workflows/bootstrap.yml` — workflow that runs the Terraform
  plan/apply **from GitHub Actions via OIDC** on demand (`workflow_dispatch`);
  the canonical loop-closing apply (`make bootstrap-apply` is the local
  break-glass equivalent).
- **ADR-0014** Terraform state model documented.
- **ADR-0024** Break-glass procedure.

## Dependencies

- Tenant admin access for the initial human-run step.
- Public DNS registrar credentials (out of band).

## Decisions / ADRs to capture

- **ADR-0014** Per-stage Terraform state files with AzureRM backend +
  CMK + blob lease lock; **no** Terragrunt.
- **ADR-0024** Break-glass: **2 cloud-only accounts**, sealed credentials in
  geographically-separated physical safes, PIM-eligible roles, alerting on
  activation.
- **ADR-0025** OIDC federation policy — one app per stage, federated with an
  **environment-scoped** subject `repo:org/repo:environment:<env>` only; branch
  gating comes from the GitHub Environment deployment-branch policy, not a
  branch-scoped subject.
- **ADR-0048** Runner connectivity model — choice between (a) GH-hosted
  runners with IP allowlist in Phase 1 → PE-only after Stage 03 via
  self-hosted runner / Azure DevOps Microsoft-hosted runner with VNet
  injection, OR (b) Azure-hosted self-hosted runner scale set in the hub.

## Technologies

| Concern | Choice |
|---------|--------|
| State backend | Azure Storage (`azurerm` provider) + CMK; Phase-1 IP-firewalled, Phase-2 Private Endpoint (Stage 03 retrofit) |
| State locking | Azure blob lease |
| Bootstrap identities | Entra ID app registrations + federated creds |
| Bootstrap secrets | Azure Key Vault (RBAC); same two-phase access posture |
| Bootstrap automation | `az cli` + bash (one-off); Terraform after |
| Break-glass | 2 cloud-only Entra accounts + PIM + Azure Monitor alert (Defender subscription posture added Stage 02) |
| Runner connectivity | ADR-0048 |

## Acceptance criteria

1. From an existing Azure subscription, a Global Admin can run
   `bootstrap-init.sh` and obtain a working OIDC app registration + state account
   in <30 minutes.
2. The bootstrap workflow runs Terraform apply from GitHub Actions via OIDC and
   re-applies the bootstrap infra idempotently (drift detection only).
3. Break-glass activation is alerted in Azure Monitor (Stage 02 configures
   Defender for Cloud posture on onboarded subscriptions).
4. **No long-lived secrets** exist in the repo or GitHub repo secrets after
   this stage.
5. Documented Phase 2 retrofit plan exists and is referenced from Stage 03
   (no implementation here; just the contract).

## Risks

- **Lost state-account access** is catastrophic → CMK keys must be replicated
  to a second Key Vault in another region; soft-delete + versioning.
- **OIDC trust scope too broad** → enforce `environment:` claim mapping;
  branch protection + required reviewers on `bootstrap.yml`.
- **Tenant-admin role overuse** during bootstrap → step-by-step runbook
  minimises portal time; PIM-time-bounded activation.
- **Phase 1 IP-allowlist drift** as GitHub egress IPs change → avoided by adding
  the runner's egress IP just-in-time per run (and removing it afterward) rather
  than maintaining a standing GitHub IP allowlist; the only standing entries are
  break-glass operator IPs until the Phase 2 PE retrofit.
- **Bootstrap app-reg over-permissioning** — the deploy identity gets only
  Contributor + User Access Administrator + Storage/KV data-plane roles scoped
  to `rg-pe-tfstate-*`, and **no** Microsoft Graph permissions at all
  (ADR-0025). Root management-group Contributor / Policy Contributor are not
  needed by Stage 02's subscription baseline and remain an explicit opt-in only
  for future tenant-scope work.
