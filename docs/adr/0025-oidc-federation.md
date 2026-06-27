# ADR-0025: GitHub to Azure OIDC federation and a zero-Graph deploy identity

- Status: accepted
- Date: 2026-06-09
- Capability: Azure foundation

## Context

All platform automation runs in GitHub Actions and must authenticate to Azure
without long-lived secrets (acceptance criterion 4: no long-lived secrets in the
repo or in GitHub secrets). Azure supports OpenID Connect (OIDC) federation,
where an Entra ID application trusts short-lived GitHub Actions tokens for a
specific repository and environment, exchanging them for Azure access tokens.

Two questions follow: (1) how is the federation subject scoped, and (2) who
creates and owns the Entra applications, service principals, and federated
credentials. The naive answer — let Terraform manage the app registrations — is
attractive for desired-state reasons but forces the deploy identity to hold
Microsoft Graph write permissions (`Application.ReadWrite.*`). An automation
identity that can create and modify app registrations (including its own
federated credentials) is a significant privilege-escalation and persistence
risk: it can mint new trust relationships for itself.

## Decision

**OIDC federation, environment-scoped subjects, and a deploy identity with zero
Microsoft Graph permissions.**

1. **OIDC, no secrets.** GitHub Actions authenticates to Azure with federated
   credentials. No client secrets or certificates are created or stored. The
   workflow surfaces configuration as GitHub Actions **variables**, not secrets.

2. **Subject = environment.** The federated credential subject is
   `repo:<owner>/<repo>:environment:<environment>` (for Azure foundation,
   `environment:bootstrap`). Branch gating is enforced by the GitHub Environment
   deployment-branch policy (ADR-0023), not by a branch-scoped subject. This
   keeps one credential per environment and lets environment protection rules
   (required reviewers, branch restrictions) govern who can deploy.

3. **Identity lifecycle lives in `bootstrap-init.sh`, not Terraform.** The Entra
   application, service principal, and federated credential are created by the
   Global Administrator running `scripts/bootstrap/bootstrap-init.sh`. Terraform
   (`_bootstrap`) manages **only Azure ARM resources** (the `azurerm` and `time`
   providers); it does not use the `azuread` provider and is never granted any
   Microsoft Graph permission. This is a deliberate deviation from the roadmap
   deliverable wording ("state.tf: state, KV, OIDC app regs"): managing OIDC apps
   in Terraform would require Graph write on the deploy identity, which we reject.

4. **Least-privilege Azure roles.** `bootstrap-init.sh` grants the bootstrap
   service principal only:
   - `Contributor` on `rg-pe-tfstate-<loc>` (manage state, Key Vault, monitoring);
   - `User Access Administrator` **scoped to that same resource group**, so
     Terraform can manage the user-assigned identity's Key Vault role assignment
     (and only within the state resource group);
   - `Storage Blob Data Contributor` on the state account (read/write state);
   - `Key Vault Crypto Officer` and `Key Vault Secrets Officer` on the seed vault.

   Root management group roles (`Contributor`, `Resource Policy Contributor`) are
   an explicit, off-by-default opt-in (`--grant-root-mg`) for future
   tenant-scope work, not required by subscription baseline, and never tenant-wide `Graph.*`
   or `Owner` at subscription scope.

5. **Later capabilities own their identities.** Each later capability provisions its own
   federated identity and scopes through the same admin-run pattern; the bootstrap
   identity is not a factory for other identities. Azure foundation deliberately ships only
   the single `sp-pe-bootstrap-<loc>` app; generalizing `bootstrap-init.sh` into a
   reusable per-capability identity helper (parameterized app name, environment subject,
   and role set) is a future hardening item, so later capabilities do not reuse the
   bootstrap identity or hand it broader root-management-group roles.

## Consequences

- The deploy identity cannot create, read, or modify any Entra object, removing a
  whole class of escalation and persistence risk.
- App registration and federated-credential creation are a one-time human step
  (Global Admin), documented and idempotent, rather than CI-managed state.
- `User Access Administrator` is intentionally granted, but scoped to the state
  resource group only; it is required for Terraform to manage the CMK identity's
  role assignment.
- Adding a new environment or repository requires a Global Admin to add a
  federated credential; this is an accepted, auditable manual control.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Terraform manages app registrations (`azuread`) | Requires Microsoft Graph write on the deploy identity; unacceptable escalation/persistence risk. |
| Branch-scoped OIDC subject (`ref:refs/heads/main`) | Couples trust to a branch name; environment protection rules are the stronger, reviewable control. |
| Client secret or certificate credentials | Long-lived secrets that violate acceptance criterion 4. |
| Single subscription-Owner service principal | Over-privileged; breaks least-privilege and blast-radius goals. |

## References

- [Azure foundation](../how-it-works/foundation.md)
- [`scripts/bootstrap/bootstrap-init.sh`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/scripts/bootstrap/bootstrap-init.sh)
- [`.github/workflows/bootstrap.yml`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/.github/workflows/bootstrap.yml)
- [ADR-0023: SCM branching and GitHub Environments](0023-scm-branching.md)
- [ADR-0014: Terraform remote state model](0014-terraform-state.md)
