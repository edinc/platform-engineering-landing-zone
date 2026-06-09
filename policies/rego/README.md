# OPA/Rego policies

Terraform plan-time assertions live here and are tested with `conftest`.

The initial Stage 00 policy validates the mandatory Azure tag taxonomy from
`plan/plan.md` section 10 against Terraform plan JSON fixtures.
