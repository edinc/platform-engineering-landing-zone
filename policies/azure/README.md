# Azure Policy

Custom Azure Policy **initiatives** (policy set definitions) for the platform's
optional/reference compliance policy pack. The JSON files under
[`initiatives/`](initiatives/) are reviewable source of truth for ALZ
administrators, and a credential-free guard validates their structure and
security-critical semantics in CI.

The Stage 02 Terraform stack does **not** render or assign these initiatives.
Tenant/MG-scoped policy assignment is owned by the existing Azure Landing Zone.

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
├── firewall/
│   └── allowlist.json              # Stage 03 Azure Firewall Premium FQDN allowlist
└── README.md
```

## Initiative JSON schema

Each file is a single Azure Policy initiative object:

| Field | Required | Meaning |
|-------|----------|---------|
| `name` | yes | Policy set definition name if an ALZ owner imports it |
| `displayName` | yes | Human-readable display name |
| `description` | yes | Purpose and rollout notes |
| `metadata` | yes | Version/category/source/owner metadata |
| `parameters` | optional | Initiative-level params, e.g. `effect` |
| `policyDefinitionGroups[]` | optional | Initiative grouping metadata |
| `policyDefinitions[]` | yes | Built-in policy references |

Each `policyDefinitions[]` entry:

| Field | Required | Meaning |
|-------|----------|---------|
| `policyDefinitionReferenceId` | yes (unique) | Stable reference ID inside the initiative |
| `policyDefinitionId` | yes (pinned built-in GUID) | Full built-in policy definition ID |
| `parameters` | optional | Parameter values, often `"[parameters('effect')]"` |
| `groupNames` | optional | Policy group names |

Built-in `policyDefinitionId` GUIDs are **pinned** and verified against the
canonical [`Azure/azure-policy`](https://github.com/Azure/azure-policy)
repository. Change a GUID only with a re-verified value and a review.

## How it is used

The initiatives are optional/reference artifacts. An external ALZ owner may
import and assign them through their ALZ pipeline, or use them as a comparison
point for equivalent existing initiatives. This repository validates them in CI
because they encode platform invariants that should not regress:

- mandatory tag coverage;
- private-link/public-network-access intent;
- AKS policy posture that explicitly avoids the Gatekeeper-based AKS Policy
  add-on because Kyverno is the in-cluster admission engine.

## Validation

Semantic guarantees are enforced by
[`scripts/policy/validate_azure_initiatives.py`](../../scripts/policy/validate_azure_initiatives.py)
and
[`scripts/policy/validate_firewall_allowlist.py`](../../scripts/policy/validate_firewall_allowlist.py)
(`make policy-test-azure`), which assert:

- well-formedness and pinned-GUID format;
- unique `policyDefinitionReferenceId` values within an initiative;
- **Stage 02 criterion 3** — `tag-baseline` covers all eight mandatory tags on
  both resources and resource groups;
- **Stage 02 criterion 8** — `aks-baseline` contains **no** AKS Policy
  (Gatekeeper) add-on GUID and uses **no** `Deny` effect;
- `private-link-required` defaults its `effect` to `Audit`.
- **Stage 03 egress** — the firewall allowlist is well-formed, uses only
  explicit allow collections, and still covers the required Azure, GitHub,
  package-manager, container-registry, Ubuntu, Docker Hub, and Sigstore FQDNs.

## Adding or changing an initiative

1. Edit or add the JSON under `initiatives/` (pin and verify any new GUID) or
   `firewall/allowlist.json`.
2. Update this README if the policy pack's inventory or guarantees change.
3. Run `make policy-test-azure validate`.
4. Coordinate any actual assignment/effect change with the external ALZ owner and
   the [policy-exception workflow](../../docs/runbooks/policy-exception.md).

> Azure Policy here governs the **Azure control plane only**. Terraform
> plan-time assertions live in `policies/rego/` (conftest); Kubernetes admission
> lives in `policies/kyverno/` (ADR-0047).
