# Azure Policy

Custom Azure Policy **initiatives** (policy set definitions) for the platform
compliance baseline. The JSON files under [`initiatives/`](initiatives/) are the
**single source of truth**; the ALZ Terraform stack renders them into
`azurerm_policy_set_definition` resources, and a credential-free guard validates
their structure and semantics in CI.

See [ADR-0011](../../docs/adr/0011-compliance-baseline.md) (baseline),
[ADR-0027](../../docs/adr/0027-policy-exception.md) (exceptions), and
[ADR-0047](../../docs/adr/0047-policy-testing-split.md) (why Azure Policy, Rego,
and Kyverno are tested separately).

## Layout

```
policies/azure/
├── initiatives/
│   ├── tag-baseline.json           # Deny missing mandatory tags (resources + RGs)
│   ├── private-link-required.json  # Audit public network access (Storage, KV, ACR, PG)
│   └── aks-baseline.json           # Audit AKS identity controls; NO Gatekeeper add-on
└── README.md
```

## Initiative JSON schema

Each file is a single object consumed by
[`alz/initiatives.tf`](../../infrastructure/terraform/alz/initiatives.tf):

| Field | Required | Maps to |
|-------|----------|---------|
| `name` | yes | `azurerm_policy_set_definition.name` |
| `displayName` | yes | `display_name` |
| `description` | yes | `description` |
| `metadata` | yes | `metadata` (JSON-encoded) |
| `parameters` | optional | `parameters` (initiative-level params, e.g. `effect`) |
| `policyDefinitionGroups[]` | optional | `policy_definition_group` blocks (`name`, `displayName`, `description`) |
| `policyDefinitions[]` | yes | `policy_definition_reference` blocks |

Each `policyDefinitions[]` entry:

| Field | Required | Maps to |
|-------|----------|---------|
| `policyDefinitionReferenceId` | yes (unique) | `reference_id` |
| `policyDefinitionId` | yes (pinned built-in GUID) | `policy_definition_id` |
| `parameters` | optional | `parameter_values` (often `"[parameters('effect')]"`) |
| `groupNames` | optional | `policy_group_names` |

Built-in `policyDefinitionId` GUIDs are **pinned** and verified against the
canonical [`Azure/azure-policy`](https://github.com/Azure/azure-policy)
repository. Change a GUID only with a re-verified value and a review.

## How Terraform consumes it

`initiatives.tf` does `jsondecode(file(...))` for each initiative, so a malformed
JSON file fails `terraform validate` (and therefore CI). Initiative-level
`parameters` (e.g. `effect`) are wired by the assignments in
[`assignments.tf`](../../infrastructure/terraform/alz/assignments.tf); see the
policy inventory in the [alz README](../../infrastructure/terraform/alz/README.md).

## Validation

`terraform validate` only checks that the JSON decodes. Semantic guarantees are
enforced by the credential-free guard
[`scripts/policy/validate_azure_initiatives.py`](../../scripts/policy/validate_azure_initiatives.py)
(`make policy-test-azure`), which asserts:

- well-formedness and pinned-GUID format;
- unique `policyDefinitionReferenceId` values within an initiative;
- **criterion 3** — `tag-baseline` covers all eight mandatory tags on both
  resources and resource groups;
- **criterion 8** — `aks-baseline` contains **no** AKS Policy (Gatekeeper)
  add-on GUID and uses **no** `Deny` effect (Kyverno is the single in-cluster
  engine, ADR-0036);
- `private-link-required` defaults its `effect` to `Audit`.

The same criterion 8 invariant is independently asserted by a `check {}` block in
`alz/initiatives.tf` (defense in depth).

## Adding or changing an initiative

1. Edit or add the JSON under `initiatives/` (pin and verify any new GUID).
2. If new, register it in `local.initiative_files` in `alz/initiatives.tf` and
   add an assignment in `alz/assignments.tf`.
3. Run `make policy-test-azure validate` and update the alz README policy
   inventory table.
4. Effects move toward `Deny` only through the
   [policy-exception workflow](../../docs/runbooks/policy-exception.md) after the
   exemption inventory is drained.

> Azure Policy here governs the **Azure control plane only**. Terraform
> plan-time assertions live in `policies/rego/` (conftest); Kubernetes admission
> lives in `policies/kyverno/` (ADR-0047).
