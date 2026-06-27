# ADR-0039: PagerDuty and Teams alert routing

- Status: accepted
- Date: 2026-06-12
- Capability: observability, SRE & FinOps

## Context

The platform needs severity-aware alert routing before it exposes golden paths.
Production-like environments require a paging integration; demo environments
need a lower-cost route that still exercises Azure Monitor Action Groups.

## Decision

Use Azure Monitor Action Groups as the Azure-native routing boundary. For
nonprod and prod, route SEV1/SEV2 alerts through a PagerDuty ITSM connector using
the Action Group `itsm_receiver` path. For demo, route to Teams through a
webhook receiver. SEV3 alerts are treated as digest/ticket notifications.

Alert rules must carry `severity` labels and `runbook_url` annotations. Terraform
keeps receiver endpoints as variables so no webhook URLs, connector IDs, or
workspace IDs are committed.

## Consequences

- Azure Monitor remains the control-plane alert integration point.
- PagerDuty configuration is required before enabling Action Groups in non-demo
  profiles.
- Demo stays cost-conscious while exercising the same Action Group contract.
- Teams webhook URLs and PagerDuty connector identifiers must be supplied through
  protected variables or secret stores.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Custom PagerDuty webhook only | Bypasses the Azure-native ITSM connector path selected for observability, SRE & FinOps. |
| Email-only alerting | Insufficient for SEV1 paging and escalation. |
| In-cluster Alertmanager as the only router | Useful for Kubernetes-local alerts, but Azure control-plane alerts still need Action Groups. |

## References

- [`infrastructure/terraform/platform/monitoring.tf`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/infrastructure/terraform/platform/monitoring.tf)
- [`infrastructure/terraform/platform/monitoring.tf`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/infrastructure/terraform/platform/monitoring.tf)
- [observability, SRE & FinOps](../how-it-works/observability-sre-finops.md)
