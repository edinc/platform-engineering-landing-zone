# `_bootstrap` — Terraform remote state, secret zero, and OIDC trust root

This stack is the root of trust for the whole platform ("turtles all the way
down"). It provisions the minimum infrastructure that every later stage depends
on, so that all subsequent Terraform runs from GitHub Actions with **no
long-lived secrets**:

- `rg-pe-tfstate-<loc>` — resource group for state, the seed Key Vault, and
  bootstrap monitoring.
- `stpetf<loc><suffix>` — RA-GRS, TLS 1.2, double-encrypted, Entra-ID-only
  (`shared_access_key_enabled = false`) state storage account with one blob
  container per stage and a customer-managed key (CMK).
- `kv-pe-boot-<loc>-<suffix>` — seed Key Vault (RBAC, purge protection) holding
  the state CMK.
- `id-pe-tfstate-cmk-<loc>` — user-assigned identity the state account uses to
  reach the CMK.
- `log-pe-bootstrap-<loc>` + break-glass action group and sign-in alert
  (acceptance criterion 3).

Entra ID applications, service principals, and federated credentials are **not**
managed here — they are created by `scripts/bootstrap/bootstrap-init.sh` so the
deploy identity holds zero Microsoft Graph permissions (ADR-0025).

## Why two steps

You cannot store Terraform state in a backend that does not exist yet, and you
cannot authenticate with OIDC to an app registration that has not been created.
So bootstrapping is split:

| Step | Who / where | Tool | Creates |
| --- | --- | --- | --- |
| 1. `bootstrap-init.sh` | Global Admin, once, locally | `az` CLI | RG, state account, `bootstrap` container, seed Key Vault, bootstrap Entra app + SP + federated credential, least-privilege role assignments. Prints GitHub **variables** (not secrets). |
| 2. `bootstrap-import` | Operator, once, locally | Terraform | One-off adoption: imports the step-1 resources (RG, state account, `bootstrap` container, seed Key Vault) into Terraform state so the next apply reconciles rather than re-creates them. |
| 3. Apply (the `bootstrap` **workflow** via OIDC; `make bootstrap-apply` locally) | GitHub Actions (canonical) or operator (break-glass) | Terraform | Reconciles the imported resources to this desired state and adds the CMK, the remaining state containers, the firewall baseline, and monitoring. |

After the first apply the stack is **idempotent** — re-running `apply` shows drift only
(acceptance criterion 2). Full walkthrough: [`docs/runbooks/bootstrap.md`](../../../docs/runbooks/bootstrap.md).

## Usage

```bash
# Step 1 — one-off, Global Admin (see the runbook for flags)
./scripts/bootstrap/bootstrap-init.sh \
  --subscription-id <sub> --tenant-id <tenant> --name-suffix <suffix>

# Step 2 — one-off local adoption from the repo root (the bootstrap workflow does
#          not run import; it only plans/applies after the resources are adopted)
cp infrastructure/terraform/_bootstrap/backend.hcl.example      infrastructure/terraform/_bootstrap/backend.hcl
cp infrastructure/terraform/_bootstrap/terraform.tfvars.example infrastructure/terraform/_bootstrap/terraform.tfvars
# edit both with the values printed by step 1

make bootstrap-tf-init   # terraform init -backend-config=backend.hcl
make bootstrap-import    # adopt the step-1 resources into state (first run only)
make bootstrap-plan
make bootstrap-apply
```

`backend.hcl`, `terraform.tfvars`, and `*.auto.tfvars` are gitignored. In CI the
[`bootstrap` workflow](../../../.github/workflows/bootstrap.yml) writes
`backend.hcl` from the `TFSTATE_*` variables and supplies the stack inputs as
`TF_VAR_*` environment variables from GitHub Actions variables — no
`terraform.tfvars` file is written.

## Network posture (Phase 1 → Phase 2)

The state account and Key Vault use a **public endpoint with a default-deny
firewall** plus a break-glass IP allowlist and the `AzureServices` bypass (the
latter is required for storage CMK access). The GitHub-hosted runner egress IP
is added just-in-time by the workflow before `terraform init` and also passed to
Terraform via `TF_VAR_runner_ip_cidrs`, so Terraform owns and drift-detects the
**full** `ip_rules` set (`allowed_ip_cidrs` + the transient runner IP) without
evicting its own state access mid-apply; the workflow's `always()` cleanup
removes the runner entry afterward. Stage 03 retrofits Private Endpoints and
disables public access (ADR-0048, ADR-0031). The intentional `checkov:skip`
annotations in `main.tf` / `state.tf` document each Phase 1 deferral.

`firewall_default_action` defaults to `Deny`. Use `Allow` only in a gitignored
local `terraform.tfvars` with `local_recovery_mode_enabled = true` and the
required acknowledgement for temporary local recovery/integration when Azure
data-plane calls egress through changing service IPs; CI runner mode is guarded
from using this bypass.

## Inputs

See [`variables.tf`](./variables.tf) and
[`terraform.tfvars.example`](./terraform.tfvars.example). Required:
`subscription_id`, `tenant_id`, `name_suffix`.

## Outputs

See [`outputs.tf`](./outputs.tf). `backend_config_hint` mirrors the values for
this stack's own backend; the remaining outputs feed later stages.

## Decisions

- ADR-0014 — Terraform remote state model (container-per-stage, AAD auth, CMK).
- ADR-0024 — break-glass identities and activation alerting.
- ADR-0025 — GitHub to Azure OIDC federation and the zero-Graph deploy identity.
- ADR-0048 — runner connectivity Phase 1 (IP allowlist) to Phase 2 (Private Endpoints).
