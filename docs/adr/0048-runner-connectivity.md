# ADR-0048: Runner connectivity model (Phase 1 IP allowlist to Phase 2 Private Endpoints)

- Status: accepted
- Date: 2026-06-09
- Stage: Stage 01 - Bootstrap and secret zero

## Context

The Terraform state account and seed Key Vault hold the most sensitive platform
data, so they run with a default-deny firewall. But Stage 01 has no virtual
network, no private DNS, and no self-hosted runners yet — those are built in
Stage 03 (connectivity). GitHub-hosted runners have dynamic, unpredictable
egress IPs, which creates a chicken-and-egg problem: a default-deny state account
cannot be reached by the runner that needs to initialize Terraform against it.

We need a secure-enough connectivity model for Phase 1 that does not block the
bootstrap, with a clear path to private networking once it exists.

## Decision

**Phase 1: public endpoint with a default-deny firewall plus just-in-time runner
allowlisting. Phase 2 (Stage 03): Private Endpoints and disabled public access.**

Phase 1:

- The state account and Key Vault keep `public_network_access_enabled = true`
  with `default_action = "Deny"`, a break-glass operator IP allowlist
  (`allowed_ip_cidrs`), and the `AzureServices` bypass (required for storage CMK
  access).
- The bootstrap workflow performs a **preflight step** that adds the runner's
  current egress IP to both firewalls (via OIDC-authenticated `az`) before
  `terraform init` — this is unavoidable because reading remote state is a
  data-plane operation that the default-deny firewall would otherwise block.
- The same runner IP is passed to Terraform as `TF_VAR_runner_ip_cidrs`, which is
  merged with `allowed_ip_cidrs` into the firewall `ip_rules`. Terraform therefore
  owns and drift-detects the **full** allowlist (so the break-glass baseline is
  actually enforced, not silently dropped) while never evicting its own state
  access mid-apply. An `always()` cleanup step removes the transient runner IP
  again; the next run re-adds and reconciles it, so only the ephemeral runner
  entry — never the operator baseline — varies between runs.

Phase 2 (Stage 03):

- Private Endpoints for the state account and Key Vault, private DNS, and
  VNet-integrated (self-hosted) runners replace the public endpoint and the IP
  allowlist. `public_network_access_enabled` is set to `false` and the
  just-in-time allowlisting step is removed.

The intentional Phase 1 posture is recorded as narrowly-scoped `checkov:skip`
annotations (CKV_AZURE_59, CKV_AZURE_189, CKV2_AZURE_32, CKV2_AZURE_33) that
reference this ADR, so the deferral is explicit and auditable rather than a
silent suppression.

## Consequences

- Phase 1 exposes a public endpoint, but access is default-deny, time-bounded for
  the runner, and restricted to a small operator allowlist otherwise.
- The workflow must always run the cleanup step so transient runner IPs do not
  accumulate on the firewalls; the cleanup is fail-loud (it fails the run if a
  removal errors) because GitHub-hosted runner egress IPs are shared Azure ranges
  and a stale allowlist entry is a real exposure.
- Stage 03 must remove the just-in-time step and flip public access off as part
  of the private-networking retrofit; this ADR is the cross-reference from Stage
  03 back to the Phase 1 decision.
- `AzureServices` bypass remains required for the storage customer-managed key
  integration even after Private Endpoints land.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Private Endpoints in Stage 01 | No VNet, DNS, or private runners exist yet; would block the bootstrap. |
| Allowlist GitHub's published meta IP ranges | Very large, frequently changing range; effectively public and high-churn. |
| Leave the state account fully public | Unacceptable exposure for the most sensitive platform data. |
| Self-hosted runners in Stage 01 | Pulls Stage 03 connectivity work forward; out of scope for secret zero. |

## References

- [`plan/stages/stage-01-bootstrap-secret-zero.md`](../../plan/stages/stage-01-bootstrap-secret-zero.md)
- [`.github/workflows/bootstrap.yml`](../../.github/workflows/bootstrap.yml)
- [`infrastructure/terraform/_bootstrap/state.tf`](../../infrastructure/terraform/_bootstrap/state.tf)
- [ADR-0031: Default-deny egress and FQDN allowlist](../adr/README.md) (Stage 03)
