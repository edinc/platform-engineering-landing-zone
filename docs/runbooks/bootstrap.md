# Runbook: Bootstrap and secret zero (Stage 01)

This runbook takes an **empty (or brownfield) Azure subscription** to the point
where every later stage deploys from GitHub Actions via OIDC, with Terraform
state in Azure and a documented break-glass path — with **no long-lived
secrets**. Target time for a Global Administrator: **under 30 minutes**
(acceptance criterion 1).

Related decisions: [ADR-0014](../adr/0014-terraform-state.md) (state),
[ADR-0024](../adr/0024-break-glass.md) (break-glass),
[ADR-0025](../adr/0025-oidc-federation.md) (OIDC),
[ADR-0048](../adr/0048-runner-connectivity.md) (runner connectivity).

## Overview

```
bootstrap-init.sh        make bootstrap-import        bootstrap workflow
(Global Admin, az CLI) -> (adopt into Terraform) ---> (OIDC, repeatable apply)
  secret zero               first-run only               drift-only thereafter
```

| Phase | Actor | Creates / does |
| --- | --- | --- |
| 1. Init | Global Admin, local | RG, state account, `bootstrap` container, seed Key Vault, Entra app + SP + OIDC credential, role assignments |
| 2. Wire | Global Admin, local | Set GitHub Actions **variables** on the `bootstrap` environment |
| 3. Adopt | Operator, local | `make bootstrap-tf-init` then `make bootstrap-import` |
| 4. Apply | GitHub Actions | `plan`/`apply` via the bootstrap workflow (adds CMK, containers, firewall, monitoring) |
| 5. Post-apply | Global Admin | Entra diagnostic setting + break-glass accounts |

## Prerequisites

- A subscription where you hold **Owner** (to create role assignments) and
  **Global Administrator** in Entra ID (to create the app registration).
- `az` CLI (logged in: `az login --tenant <tenant-guid>`), `jq`, `gh`, and the
  repo toolchain (`mise install`, which provides the pinned Terraform).
- The `bootstrap` GitHub Environment already exists (created in Stage 00,
  ADR-0023). Confirm its deployment-branch policy restricts deploys to `main`.

## 1. Create secret zero

```bash
./scripts/bootstrap/bootstrap-init.sh \
  --subscription-id <sub-guid> \
  --tenant-id <tenant-guid> \
  --name-suffix <2-8 lowercase alnum>      # short, stable, globally unique
```

Useful flags: `--location` / `--location-short` (default `swedencentral` / `sec`),
`--key-vault-sku premium` (only if you will use an HSM-backed CMK),
`--grant-root-mg` (legacy opt-in root management group roles for explicitly
documented future tenant-scope work; Stage 02 does not need it),
`--dry-run` (preview without changes).

The script is **idempotent** — re-run it safely. It prints the GitHub Actions
variables to set in the next step. It grants the deploy identity **no Microsoft
Graph permissions** (ADR-0025).

> Brownfield: if the resource group, storage account, or Key Vault already
> exist, the script adopts them in place and only fills gaps. A soft-deleted
> Key Vault of the same name is **recovered** automatically (purge protection).

## 2. Wire up GitHub Actions variables

Set the printed values as **variables** (not secrets) on the `bootstrap`
environment. With the GitHub CLI:

```bash
gh variable set AZURE_CLIENT_ID          --env bootstrap --body "<appId>"
gh variable set AZURE_TENANT_ID          --env bootstrap --body "<tenant-guid>"
gh variable set AZURE_SUBSCRIPTION_ID    --env bootstrap --body "<sub-guid>"
gh variable set TFSTATE_RESOURCE_GROUP   --env bootstrap --body "rg-pe-tfstate-sec"
gh variable set TFSTATE_STORAGE_ACCOUNT  --env bootstrap --body "stpetfsec<suffix>"
gh variable set TFSTATE_CONTAINER        --env bootstrap --body "bootstrap"
gh variable set BOOTSTRAP_NAME_SUFFIX    --env bootstrap --body "<suffix>"
gh variable set BOOTSTRAP_LOCATION       --env bootstrap --body "swedencentral"
gh variable set BOOTSTRAP_LOCATION_SHORT --env bootstrap --body "sec"
# REQUIRED: must equal bootstrap-init.sh's --soft-delete-days (immutable on the Key Vault).
gh variable set BOOTSTRAP_SOFT_DELETE_DAYS --env bootstrap --body "90"
```

Optionally set the **persistent Terraform inputs** the workflow owns and
drift-detects (each is mapped to a `TF_VAR_*` only when present). Values are
HCL/JSON, so lists use bracket syntax:

```bash
# Standing break-glass operator allowlist (bare IP for single hosts, never /32).
gh variable set BOOTSTRAP_ALLOWED_IP_CIDRS      --env bootstrap --body '["203.0.113.10"]'
# Enable the break-glass sign-in alert (acceptance criterion 3).
gh variable set BOOTSTRAP_BREAK_GLASS_UPNS      --env bootstrap --body '["breakglass-1@contoso.onmicrosoft.com","breakglass-2@contoso.onmicrosoft.com"]'
gh variable set BOOTSTRAP_ALERT_EMAIL_RECEIVERS --env bootstrap --body '["platform-oncall@example.com"]'

# ONLY if you ran bootstrap-init.sh with --key-vault-sku premium for an HSM-backed
# CMK: set both so CI does not converge the vault/key back to the standard/RSA
# defaults (key_type is immutable on the CMK key). Omit both for standard/RSA.
gh variable set BOOTSTRAP_KEY_VAULT_SKU --env bootstrap --body 'premium'
gh variable set BOOTSTRAP_KEY_TYPE      --env bootstrap --body 'RSA-HSM'
```

If `BOOTSTRAP_ALLOWED_IP_CIDRS` is left unset, the firewalls keep only the
just-in-time runner IP during each run, leaving **no standing human break-glass
path** to the state account / Key Vault data plane until you add one.

For local integration or recovery runs from environments whose Azure data-plane
egress cannot be represented by stable IP rules, set
`firewall_default_action = "Allow"` only in the gitignored local
`terraform.tfvars`, together with `local_recovery_mode_enabled = true` and the
exact acknowledgement required by `variables.tf`. The committed default remains
`Deny`, and CI keeps the default-deny posture because runner IP mode is
incompatible with the local recovery guard.

There are no secrets to store — that is the point of OIDC (acceptance criterion 4).

> Stage 02 was renamed from the previous `alz` stack to
> `subscription-baseline`. The bootstrap stack now keeps both the legacy `alz`
> container and the new `subscription-baseline` container, with state-container
> deletion protected by Terraform `prevent_destroy`. Remove `alz` only through a
> reviewed state-migration change after confirming no live state blobs remain.

> **Restrict the environment before the first apply.** The OIDC federated
> credential subject is `environment:bootstrap` only, so branch safety depends
> entirely on the GitHub Environment's deployment-branch policy. In
> *Settings → Environments → bootstrap*, set **Deployment branches** to
> *Selected branches* and allow only `main` (and add required reviewers if
> desired). Without this, any branch could mint a bootstrap OIDC token (ADR-0025).

## 3. Adopt the resources into Terraform (first run only)

From the repo root, create the local config from the values the init script
printed, initialize the backend, and import:

```bash
cp infrastructure/terraform/_bootstrap/backend.hcl.example      infrastructure/terraform/_bootstrap/backend.hcl
cp infrastructure/terraform/_bootstrap/terraform.tfvars.example infrastructure/terraform/_bootstrap/terraform.tfvars
# edit both: subscription_id, tenant_id, name_suffix, location*, allowed_ip_cidrs

make bootstrap-tf-init   # terraform init -backend-config=backend.hcl
make bootstrap-import    # idempotent: imports RG, state account, bootstrap container, Key Vault
```

`backend.hcl`, `terraform.tfvars`, and `*.auto.tfvars` are gitignored — never
commit them.

## 4. First apply

Run the **bootstrap** workflow (Actions -> "Bootstrap (Stage 01)" ->
`workflow_dispatch`) with `action = plan`, review, then re-run with
`action = apply`. The workflow authenticates via OIDC, allowlists the runner's
egress IP on the state account and Key Vault firewalls before `terraform init`,
applies, and removes the runner IP afterward (ADR-0048).

The first apply adds the customer-managed key, the user-assigned identity, the
remaining per-stage containers, the Phase 1 firewall baseline, and break-glass
monitoring. Local equivalent (operator IP must be in `allowed_ip_cidrs`):

```bash
make bootstrap-plan
make bootstrap-apply
```

> **Local apply prerequisites:** the first apply creates the CMK key and per-stage
> containers, so an operator running it locally needs the same data-plane access
> the deploy identity has — `Contributor` + `User Access Administrator` on the
> resource group, `Storage Blob Data Contributor` on the state account, and
> `Key Vault Crypto Officer` + `Key Vault Secrets Officer` on the seed vault.
> `bootstrap-init.sh` grants the operator only `Storage Blob Data Contributor`;
> grant the rest first, or use the CI path (which runs as the bootstrap SP).

> **Network-open window:** `bootstrap-init.sh` creates the state account and Key
> Vault with their network default-action open so the local import/plan can reach
> them during adoption. The first apply flips both to default-deny with the
> Phase 1 allowlist, so run it promptly. Shared-key access is already disabled and
> the container is empty during the window, so the data plane still requires
> Entra + RBAC.

> **CMK gap (expected):** state blobs written during this first apply are
> platform-encrypted until the CMK association is created in the same run.
> Subsequent state writes are customer-managed-key encrypted.

Verify idempotency (acceptance criterion 2): re-run `plan` — it should report no
changes other than legitimate drift.

## 5. Post-apply (Global Admin)

These steps require tenant-level permissions the deploy identity intentionally
does not have (ADR-0025).

### 5a. Route Entra sign-in logs to the bootstrap workspace

Needed so the break-glass sign-in alert receives data (acceptance criterion 3).
Replace `<workspace-id>` with the `log_analytics_workspace_id` output:

Use the portal (simplest, version-independent): **Entra ID → Monitoring →
Diagnostic settings → Add diagnostic setting**, enable the `SignInLogs` category,
and send it to the `log-pe-bootstrap-sec` workspace.

Equivalent via the Azure Monitor REST API — Entra diagnostic settings live under
the tenant-level `microsoft.aadiam` provider, so use `az rest` (not
`az monitor diagnostic-settings`, which does not target that provider). Replace
`<workspace-id>` with the `log_analytics_workspace_id` output (a full resource ID):

```bash
az rest --method put \
  --url "https://management.azure.com/providers/microsoft.aadiam/diagnosticSettings/entra-to-bootstrap-law?api-version=2017-04-01-preview" \
  --body '{"properties":{"workspaceId":"<workspace-id>","logs":[{"category":"SignInLogs","enabled":true}]}}'
```

The `SignInLogs` diagnostic category lands in the `SigninLogs` table that the
break-glass alert query reads.

### 5b. Create the break-glass accounts and enable the alert

Follow [ADR-0024](../adr/0024-break-glass.md): create two cloud-only Entra
accounts, seal their credentials in two geographically separated safes, make them
PIM-eligible Global Admins, and exclude them from Conditional Access lockout.
Then provide their UPNs (and on-call addresses) to the stack and re-apply, which
creates the Azure Monitor sign-in alert:

- **CI (the normal path):** set the `BOOTSTRAP_BREAK_GLASS_UPNS` and
  `BOOTSTRAP_ALERT_EMAIL_RECEIVERS` environment variables (see section 2), then
  re-run the **bootstrap** workflow with `action = apply`.
- **Local:** set `break_glass_upns` and `alert_email_receivers` in
  `terraform.tfvars` and run `make bootstrap-apply`.

Verify by signing in with one account and confirming the alert fires.

## 6. Record downstream prerequisites (DNS delegation & Sigstore egress)

Stage 01 does not configure DNS or runner egress, but it is the point at which
these later-stage prerequisites are captured so they are not forgotten.

**DNS delegation (for Stage 03 connectivity / public zones).** Confirm the parent
zone's registrar credentials are held **out of band** (password manager / sealed
break-glass safe, never in this repo). When a platform public zone is created in
a later stage, delegation is completed by adding the Azure-issued `NS` records to
the parent zone at the registrar; record the parent zone name and registrar owner
here as part of bootstrap sign-off. No delegation is performed in Stage 01.

**Sigstore egress (for Stage 03 hub firewall / Stage 06 supply chain).** Keyless
`cosign` signing and verification require outbound reachability to the Sigstore
services, so the Stage 03 hub Azure Firewall allowlist **must** include:

| Endpoint | Purpose |
| --- | --- |
| `fulcio.sigstore.dev` | Short-lived signing certificate issuance |
| `rekor.sigstore.dev` | Transparency-log inclusion proof |
| `tuf.sigstore.dev` | Trust-root (TUF) metadata |

These are recorded here as a forward reference; the allowlist itself is
implemented with the hub firewall in Stage 03 (cross-reference ADR-0048).

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `terraform init` cannot read state from CI | Runner IP not allowlisted yet; the workflow's preflight handles this. Locally, the firewall denies by default after the first apply, so add your IP out-of-band first (`az storage account network-rule add ... --ip-address <ip>` / portal) to reach the backend, then persist it in `allowed_ip_cidrs` (Terraform now owns and enforces that baseline) and re-apply. |
| Container creation fails in `bootstrap-init.sh` | Shared-key access is disabled; the script grants you `Storage Blob Data Contributor` and waits 30s for propagation. Re-run if RBAC was still propagating. |
| CMK association fails intermittently on first apply | RBAC propagation; the `time_sleep.cmk_rbac` (60s) covers this. Re-run `apply`. |
| Key Vault create fails with "name in use / soft-deleted" | Purge protection retains the name. `bootstrap-init.sh` recovers it automatically; otherwise `az keyvault recover --name <kv>`. |
| Locked out of the state account | Use a break-glass account / portal to add your IP to the firewall, then re-apply. |

## Phase 2 retrofit

Phase 1 uses a public endpoint with a default-deny firewall and just-in-time
runner allowlisting. **Stage 03 (connectivity)** retrofits Private Endpoints,
private DNS, and VNet-integrated runners, sets `public_network_access_enabled =
false`, and removes the just-in-time allowlisting — see
[ADR-0048](../adr/0048-runner-connectivity.md).
