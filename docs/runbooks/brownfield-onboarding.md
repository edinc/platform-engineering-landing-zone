# Runbook: Brownfield onboarding (Stage 02)

This runbook onboards an **existing** Azure tenant or subscription to the ALZ
baseline without breaking what is already running. It is the dry-run procedure
behind Stage 02 **acceptance criterion 7**: validate discovery and an
audit-only policy rollout against a real, non-empty subscription before any
effect is moved to `Deny`.

The guiding rule is **audit first, deny later** ([ADR-0011](../adr/0011-compliance-baseline.md)):
the only `Deny` at Stage 02 is mandatory tags, and even that is enabled only
after the untagged inventory is tagged or exempted.

Related decisions: [ADR-0011](../adr/0011-compliance-baseline.md) (baseline),
[ADR-0028](../adr/0028-subscription-topology.md) (subscription topology),
[ADR-0027](../adr/0027-policy-exception.md) (exceptions).

## Overview

```
discover (read-only)  ->  associate MG (optional)  ->  assign audit-only  ->  drain inventory  ->  enable Deny
brownfield-discovery.sh    subscription_associations    cis_enforce=false        tag or exempt        tag_baseline_enforce
                                                         tag_baseline default     (ADR-0027)            stays/Deny
```

| Phase | Writes? | What happens |
| --- | --- | --- |
| 1. Discover | **No** | Inventory MGs, existing assignments, Defender, untagged resources |
| 2. Associate | Yes (opt-in) | Move the test subscription under the right MG, only if you choose to |
| 3. Audit-only assign | Yes | Apply the ALZ stack with CIS `enforce=false`; tag-baseline evaluated |
| 4. Drain inventory | Yes | Tag or exempt every non-compliant resource (ADR-0027) |
| 5. Enable Deny | Yes | Keep `tag_baseline_enforce = true`; new untagged resources are denied |

## Prerequisites

- **Reader** at the management-group scope and on the test subscription is
  enough for Phase 1 (discovery). Later phases need the usual deploy identity.
- `az` CLI (logged in: `az login --tenant <tenant-guid>`), `jq`, and the repo
  toolchain (`mise install`).
- A **non-empty test subscription** you are allowed to evaluate (criterion 7).

## 1. Discover (read-only — makes no changes)

Run the discovery script. It only performs `az ... list/show` calls.

```bash
# Inspect the current subscription, hierarchy rooted at the tenant MG:
scripts/alz/brownfield-discovery.sh

# Or target a specific subscription and MG, and save JSON snapshots:
scripts/alz/brownfield-discovery.sh \
  -s <test-subscription-id> \
  -g <management-group-id> \
  -o ./.discovery
```

> The `-o` snapshots contain tenant-specific inventory (subscription IDs are
> embedded in resource ARM IDs). `./.discovery` is gitignored, and the script
> **refuses** to write into any in-repo path that is not gitignored, so a routine
> `git add` cannot commit them. Treat the snapshots as ephemeral; delete them when
> done, or use a path outside the repo.

Review the five sections it prints:

1. **Signed-in context** — confirm tenant and subscription are the test target.
2. **Management-group hierarchy** — note where the subscription sits today.
3. **Existing policy assignments** — reconcile names so the baseline does not
   collide with an assignment already in place.
4. **Defender pricing** — record current tiers (demo stays Free, ADR-0011).
5. **Resources missing mandatory tags** — this is the **tag-baseline `Deny`
   blast radius**. It must reach zero (tagged or exempted) before Deny is safe.

> Criterion 7 is satisfied here: the script runs end-to-end against the existing
> subscription and produces the untagged-resource inventory, with **no writes**.

## 2. Associate the subscription to a management group (optional)

Association is **opt-in and data-driven** ([ADR-0028](../adr/0028-subscription-topology.md)):
nothing moves unless you set the subscription-ID variable for the target MG. The
ALZ stack derives its `subscription_associations` from these per-MG variables and
only creates an association for non-empty IDs, so an empty value is a no-op.
Moving a subscription changes its inherited policy and RBAC — review the blast
radius first.

```hcl
# infrastructure/terraform/alz/terraform.tfvars
# Place the test workload subscription under landingzones/corp:
corp_subscription_id = "<test-subscription-id>"

# Other optional placements (leave unset to skip):
#   connectivity_subscription_id      = "<sub-id>"
#   identity_subscription_id          = "<sub-id>"
#   associate_management_subscription = true   # places management_subscription_id under platform/management
```

If you are only validating discovery, **skip this phase** and leave these
variables unset.

## 3. Apply the baseline in audit-only mode

Apply the ALZ stack with broad enforcement off:

```hcl
cis_enforce          = false  # CIS evaluated, not enforced (DoNotEnforce)
tag_baseline_enforce = true   # tag-baseline assignment present; Deny is active for NEW resources
```

`cis_enforce = false` keeps CIS evaluation-only so no existing resource is
denied. `tag-baseline` is assigned; because Deny only acts on **create/update**,
existing untagged resources are reported as non-compliant but not deleted — they
are only a problem the next time they are modified. Plan and apply through the
normal pipeline and confirm the assignments exist:

```bash
az policy assignment list --scope "/providers/Microsoft.Management/managementGroups/<mg>" -o table
```

## 4. Drain the non-compliant inventory

For every resource the discovery script flagged:

- **Tag it** with the eight mandatory tags (`env`, `owner`, `costCenter`,
  `product`, `dataClassification`, `confidentiality`, `managedBy`, `repo`), or
- **Exempt it** with a time-bound waiver via the
  [policy-exception runbook](policy-exception.md) (ADR-0027).

Re-run discovery until the non-compliant count is zero or every remaining
resource has an active exemption:

```bash
scripts/alz/brownfield-discovery.sh -s <test-subscription-id> -o ./.discovery
```

## 5. Enable Deny with confidence

With the inventory drained, `tag_baseline_enforce = true` is now safe in
practice: new or modified resources missing a mandatory tag are denied at the
control plane, matching the plan-time Rego gate (ADR-0047). Broadening **other**
effects to `Deny` (e.g. private-link, CIS controls) is a separate, later change
that repeats phases 1, 4, and 5 for that control.

## Rollback

- To return to evaluation-only, set `cis_enforce = false` (already the default)
  and, if necessary, `tag_baseline_enforce = false`, then apply. Existing
  resources are never modified by these assignments.
- To undo an association, unset the subscription-ID variable you set in Phase 2
  (e.g. `corp_subscription_id`) and apply; the subscription returns to its
  previous parent MG (the Tenant Root Group).

## References

- [`scripts/alz/brownfield-discovery.sh`](../../scripts/alz/brownfield-discovery.sh)
- [ADR-0011: Compliance baseline](../adr/0011-compliance-baseline.md)
- [ADR-0027: Policy exception workflow](../adr/0027-policy-exception.md)
- [ADR-0028: Subscription topology](../adr/0028-subscription-topology.md)
- [Runbook: Policy exception](policy-exception.md)
