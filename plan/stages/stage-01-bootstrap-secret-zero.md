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
    - **Phase 1 (this stage)** — public endpoints **with IP allowlist**
      (GitHub-hosted runner egress IPs published in `api.github.com/meta`,
      plus a small list of break-glass operator IPs). VNets do not yet
      exist (created in Stage 03), so Private Endpoints cannot be enabled
      yet.
    - **Phase 2 (retrofit during Stage 03)** — replace the IP allowlist
      with **Private Endpoints** for the state account and seed KV; public
      access disabled; runner access via a self-hosted runner in the hub
      or via Azure DevOps / Microsoft-hosted runners with VNet integration
      (ADR-0048).
  - Containers per stage: `bootstrap`, `alz`, `connectivity`, `identity`,
    `platform`, `vending`, `cicd`, `gitops`, `observability`, `backstage`,
    `onboarding`, `golden-paths`, `dr`, `envs-demo`, `envs-nonprod`,
    `envs-prod`.
- **Seed Key Vault** `kv-pe-bootstrap-<region>` for bootstrap-time secrets (HSM
  tier optional). Purge protection on. Phase-1 IP-firewalled; PE retrofit at
  Stage 03 (same two-phase model as state).
- **GitHub ↔ Azure OIDC federation**:
  - One Entra ID *application registration* per stage (least-privilege scopes).
  - Federated credentials scoped to specific GitHub repo + branch + GitHub
    **Environment** (Environments are provisioned in Stage 00).
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
- **Bootstrap automation** — a documented two-step path:
  1. `make bootstrap-init` — *one-off* `az login` + `bicep`/`az cli` script run
     locally by a human Global Admin to create the storage account, KV, and
     OIDC app reg. This step is the **only** sanctioned use of CLI/Bicep
     in the platform (ADR-0001 exception); documented explicitly.
  2. `make bootstrap-apply` — Terraform run *from GitHub Actions via OIDC*
     against the freshly-minted state account, idempotently re-applying its
     own backing infra (proving the loop closes).

## Scope (out)

- Management groups, policy, networking (Stage 02–03).
- AKS or any workload infra (Stage 04+).

## Deliverables

- `infrastructure/terraform/_bootstrap/`
  - `main.tf`, `state.tf` (state, KV, OIDC app regs), `variables.tf`, `outputs.tf`.
- `scripts/bootstrap/bootstrap-init.sh` — the one-off pre-Terraform script.
- `docs/runbooks/bootstrap.md` — step-by-step "from empty tenant to GH-Actions
  applying Terraform".
- `.github/workflows/bootstrap.yml` — workflow that performs `bootstrap-apply`
  on demand (`workflow_dispatch`).
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
- **ADR-0025** OIDC federation policy — one app per stage, federated to
  `repo:org/repo:ref:refs/heads/main` and `repo:org/repo:environment:<env>`.
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
| Break-glass | 2 cloud-only Entra accounts + PIM + Azure Monitor alert (Defender alert added Stage 02) |
| Runner connectivity | ADR-0048 |

## Acceptance criteria

1. From a fresh tenant, a Global Admin can run `bootstrap-init.sh` and obtain
   a working OIDC app registration + state account in <30 minutes.
2. `bootstrap-apply` runs from GitHub Actions via OIDC and re-applies the
   bootstrap infra idempotently (drift detection only).
3. Break-glass activation is alerted in Azure Monitor (Stage 02 extends this
   with Defender for Cloud alerting).
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
- **Phase 1 IP-allowlist drift** as GitHub egress IPs change → automated
  weekly sync of `api.github.com/meta` to the storage-account firewall rules
  until Phase 2 retrofit completes.
- **Bootstrap app-reg over-permissioning** — initial app must have only:
  Mgmt-Group Contributor at root, Policy Contributor, Storage/KV Contributor
  on `rg-pe-tfstate-*`. No tenant-wide Graph.Write.All.
