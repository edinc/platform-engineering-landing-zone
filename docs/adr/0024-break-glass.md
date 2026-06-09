# ADR-0024: Break-glass procedure and activation alerting

- Status: accepted
- Date: 2026-06-09
- Stage: Stage 01 - Bootstrap and secret zero

## Context

The platform is governed by OIDC federation, PIM, Conditional Access, and policy
guardrails. If that control plane fails — a misconfigured Conditional Access
policy, a broken federation, an Entra outage, or an accidental lockout — there
must still be a way to recover. We cannot automate the very mechanism that
protects the automation, so break-glass is, by design, a partly manual control
with strong detection.

Acceptance criterion 3 requires that break-glass account activation is alerted in
Azure Monitor.

## Decision

**Two cloud-only break-glass accounts with sealed credentials, excluded from
automation, and an Azure Monitor sign-in alert.**

1. **Accounts.** Exactly two dedicated, cloud-only Entra ID accounts
   (`*.onmicrosoft.com`, no synced/federated identity), each with a long random
   password and a separate strong MFA method. They are assigned
   `Global Administrator` as **PIM-eligible**, not permanently active.

2. **Credential custody.** Credentials are split and sealed in two
   geographically separated physical safes; no single person holds both factors
   for both accounts. They are never stored in the repository, Key Vault, or any
   automation.

3. **Exclusions.** The break-glass accounts are excluded from Conditional Access
   policies that could lock them out (so a bad CA policy cannot block recovery)
   and are excluded from automated lifecycle and access reviews.

4. **Detection (provisioned, not documentation-only).** The `_bootstrap` stack
   provisions a Log Analytics workspace, an action group, and a scheduled query
   alert (`azurerm_monitor_scheduled_query_rules_alert_v2`) that fires on any
   sign-in by a break-glass UPN. The alert is created once the break-glass UPNs
   are supplied via `break_glass_upns`. Routing Entra `SigninLogs` into the
   workspace via an Entra ID diagnostic setting is a tenant-level operation the
   deploy identity intentionally cannot perform (ADR-0025); it is a documented
   Global-Admin post-apply step in the runbook.

5. **Procedure.** Activation, use, and mandatory post-use rotation are documented
   in `docs/runbooks/bootstrap.md`. Every activation is a reviewable security
   event.

## Consequences

- Recovery remains possible even if OIDC, PIM, or Conditional Access fail.
- Account creation and credential sealing are manual by necessity; they are not
  automatable without reintroducing the dependency they exist to bypass.
- The sign-in alert depends on the Entra diagnostic setting being wired by an
  admin; until then the alert rule exists but receives no data. This dependency
  is called out in the runbook.
- Using HSM (premium Key Vault) or additional notification channels is optional
  and can be layered on later.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| A single break-glass account | No redundancy; a single lost credential removes the recovery path. |
| Store break-glass creds in Key Vault | Couples recovery to the platform it must survive; defeats the purpose. |
| Permanent Global Admin (not PIM-eligible) | Standing privilege increases risk; PIM-eligible plus alerting is safer. |
| Documentation-only break-glass (no alert) | Fails acceptance criterion 3; activation must be detectable. |

## References

- [`plan/stages/stage-01-bootstrap-secret-zero.md`](../../plan/stages/stage-01-bootstrap-secret-zero.md)
- [`infrastructure/terraform/_bootstrap/monitoring.tf`](../../infrastructure/terraform/_bootstrap/monitoring.tf)
- [`docs/runbooks/bootstrap.md`](../runbooks/bootstrap.md)
- [ADR-0025: OIDC federation policy](0025-oidc-federation.md)
