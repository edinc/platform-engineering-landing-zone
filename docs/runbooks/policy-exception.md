# Runbook: Policy exception (Stage 02)

This runbook is the operational procedure behind
[ADR-0027](../adr/0027-policy-exception.md). Use it when a resource, resource
group, or subscription must be **temporarily** non-compliant with the
compliance baseline ([ADR-0011](../adr/0011-compliance-baseline.md)) — for
example a brownfield resource that cannot be tagged immediately, or a workload
that needs a short waiver while a fix lands.

**The baseline is never weakened to grant an exception.** You do not unassign or
disable an initiative; you create a scoped, time-bound Azure Policy *exemption*.

Related decisions: [ADR-0011](../adr/0011-compliance-baseline.md) (baseline),
[ADR-0027](../adr/0027-policy-exception.md) (this workflow),
[ADR-0024](../adr/0024-break-glass.md) (incident exemptions).

## When to use this

| Situation | Use an exemption? |
| --- | --- |
| Existing resource missing a mandatory tag, fix needs a few days | Yes — `Waiver`, narrow scope, short expiry |
| Compensating control exists (e.g. resource is private by other means) | Yes — `Mitigated` |
| You want to turn a control off for everyone | **No** — that is an ADR + baseline change, not an exemption |
| Active incident needs a control bypassed now | Use the break-glass path (ADR-0024), retro-reviewed |

## Workflow: request → approve → apply → audit

### 1. Request (as code)

Add an exemption resource in the IaC PR, scoped as narrowly as possible. Prefer
resource scope over resource group over subscription; never exempt an entire MG.

```hcl
resource "azurerm_resource_policy_exemption" "example" {
  name                 = "waiver-untagged-legacy-vm"
  resource_id          = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Compute/virtualMachines/<vm>"
  policy_assignment_id = azurerm_management_group_policy_assignment.tag_baseline.id

  exemption_category = "Waiver"            # or "Mitigated" when a compensating control exists
  expires_on         = "2026-07-09T00:00:00Z" # mandatory; see ADR-0027 max durations
  display_name       = "Legacy VM tag waiver"
  description        = "Untagged pre-existing VM; tags added under TICKET-1234. Approved in PR #NN."

  # Optionally narrow to specific references within the initiative:
  # policy_definition_reference_ids = ["requireTag-env"]
}
```

Fill the request fields:

| Field | Value |
| --- | --- |
| Scope (resource / RG / subscription) | the **narrowest** that covers the need |
| Category | `Waiver` (accepted) or `Mitigated` (compensating control) |
| Expiry | within the ADR-0027 maximum for the scope/effect |
| Justification | what, why, and the tracking ticket |
| Remediation plan | how compliance will be restored before expiry |

### 2. Approve

Get the approval required by the **ADR-0027 approver matrix** for the scope and
effect. The approval is the PR review (and any linked change ticket). Do not
self-approve subscription-scope or `Deny`-effect exemptions.

### 3. Apply

Merge through the normal IaC pipeline. The exemption is now in Terraform state
and visible in the Azure control plane. Confirm it is active:

```bash
az policy exemption list --scope "<scope>" -o table
```

### 4. Audit

- Exemptions are reviewed **before** `expires_on`. Run the brownfield discovery
  script or a compliance export to list what is still exempt:
  ```bash
  az policy exemption list --scope "<scope>" \
    --query "[].{name:name, category:exemptionCategory, expires:expiresOn}" -o table
  ```
- An expired exemption is **not** auto-renewed. If more time is needed, submit a
  **new** request with fresh approval (ADR-0027 — no silent extensions).
- When the underlying issue is fixed, remove the exemption resource in a PR so
  the control re-applies.

## Do / don't

- **Do** keep the scope and the expiry as small as the situation allows.
- **Do** link a tracking ticket and a remediation plan in every exemption.
- **Don't** set `exemption_category` without an `expires_on`.
- **Don't** unassign, `Disabled`-set, or delete an initiative to dodge a finding.
- **Don't** exempt at MG scope; that re-creates the "control off for everyone"
  problem the workflow exists to prevent.

## References

- [ADR-0027: Policy exception workflow and approver matrix](../adr/0027-policy-exception.md)
- [ADR-0011: Compliance baseline](../adr/0011-compliance-baseline.md)
- [Azure Policy exemption structure](https://learn.microsoft.com/azure/governance/policy/concepts/exemption-structure)
