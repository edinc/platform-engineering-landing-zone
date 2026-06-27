# OPA/Rego policies

Terraform plan-time assertions live here and are tested with `conftest`.

The OPA/Rego policy validates the mandatory Azure tag taxonomy (see the
[architecture reference](../../docs/architecture/README.md#tagging-taxonomy))
against Terraform plan JSON fixtures.
