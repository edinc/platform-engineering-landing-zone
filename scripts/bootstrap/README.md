# Bootstrap scripts (Stage 01)

Secret-zero automation that creates the root of trust for the platform. These
are run **once, by a Global Administrator**, against an empty or brownfield
subscription. After that, all Terraform runs from GitHub Actions via OIDC with
no long-lived secrets. Full walkthrough: [`docs/runbooks/bootstrap.md`](../../docs/runbooks/bootstrap.md).

> Stage 00 used `make bootstrap` only for local developer tooling. That is
> unrelated to the Azure bootstrap here.

| Script | When | What it does |
| --- | --- | --- |
| `bootstrap-init.sh` | Once, before any Terraform | Creates the state resource group, RA-GRS AAD-only storage account, `bootstrap` container, seed Key Vault, the bootstrap Entra app + service principal + GitHub OIDC federated credential, and least-privilege role assignments. Prints the GitHub Actions **variables** to set. Idempotent. |
| `bootstrap-import.sh` | Once, after `make bootstrap-init` | Adopts the `bootstrap-init.sh` resources into Terraform state (`terraform import`) so the first apply is drift-only. Idempotent — skips resources already in state. Invoked by `make bootstrap-import`. |

## Quick start

```bash
# 1. Authenticate as a Global Administrator
az login --tenant <tenant-guid>

# 2. Create secret zero (see --help for all flags)
./scripts/bootstrap/bootstrap-init.sh \
  --subscription-id <sub-guid> \
  --tenant-id <tenant-guid> \
  --name-suffix <2-8 lowercase alnum>

# 3. Set the printed GitHub Actions variables on the 'bootstrap' environment,
#    create the local Terraform config, then adopt + apply with Terraform:
cp infrastructure/terraform/_bootstrap/backend.hcl.example      infrastructure/terraform/_bootstrap/backend.hcl
cp infrastructure/terraform/_bootstrap/terraform.tfvars.example infrastructure/terraform/_bootstrap/terraform.tfvars
# edit both with the values printed by step 2, then:
make bootstrap-tf-init
make bootstrap-import
make bootstrap-plan
make bootstrap-apply
```

Step 2 is also available as `make bootstrap-init ARGS="--subscription-id <sub> --tenant-id <tenant> --name-suffix <suffix>"`.

Use `--dry-run` to preview `bootstrap-init.sh` without making changes, and
`--grant-root-mg` only when later ALZ stages need root management group roles.

## Security notes

- The deploy identity is granted **no Microsoft Graph permissions** (ADR-0025).
  Later stages create their own identities; this script does not grant the SP
  `Application.ReadWrite.*`.
- Role assignments are scoped to the state resource group and its storage
  account / Key Vault, plus an optional, explicit root management group opt-in.
- The scripts print GitHub Actions **variables**, never secrets. OIDC means
  there is nothing sensitive to store in the repository or in GitHub secrets.
