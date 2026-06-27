# platform-vending-bot GitHub App (tenancy vending)

This stack records the Terraform-owned parts of the `platform-vending-bot`
delivery identity:

- manages the app installation repository scope for this repo and
  `platform-cluster-state`;
- exports the app metadata and Key Vault secret name consumed by tenancy vending
  workflows.

The GitHub provider cannot create the GitHub App registration itself. Create the
App through the GitHub UI/API with the permissions in
[`docs/runbooks/vending.md`](../../../docs/runbooks/vending.md), generate a
private key, and write the private key to the Azure foundation seed Key Vault with the
runbook's `az keyvault secret set` command before applying this stack.

The private key must not be committed, stored as a GitHub secret, written to
Terraform variable files, or passed through Terraform variables. Terraform only
records the non-secret secret name and rotation due date so the PEM value never
enters Terraform state.
