# ADR-0032: Platform-internal eventing uses Azure Service Bus

- Status: accepted
- Date: 2026-06-10
- Capability: platform shared services

## Context

The platform needs an internal event bus for platform workflows, vending events,
and later automation hooks. Workload teams also need messaging services, but
their queues/topics are workload dependencies and should be vended through ASO in
later capabilities rather than owned centrally here.

## Decision

**Azure Service Bus is the default platform-internal eventing substrate for the
MVP.**

1. The platform shared services capability provisions one namespace per environment.
2. Every enabled environment uses Premium so Private Link and private-only
   networking can be enforced consistently.
3. Public network access and local SAS auth are disabled.
4. Workload queues/topics are not created in this stack; GitOps platform ASO v2 handles
   workload-owned messaging resources through a curated CRD allowlist.

## Consequences

- Platform workflows get durable, Azure-native messaging without introducing a
  Kubernetes-hosted broker.
- Premium can isolate production eventing capacity and support private access.
- Workload messaging remains explicitly vended and owned by workload teams.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Event Grid for all platform events | Better for event distribution, but Service Bus is a stronger default for command/workflow durability. |
| Kafka/Event Hubs | More operational overhead than the MVP platform eventing needs. |
| In-cluster broker | Violates the Azure-native-first and operational simplicity goals for MVP. |

## References

- [Platform shared services](../how-it-works/platform-services.md)
- [`infrastructure/terraform/platform/service-bus.tf`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/infrastructure/terraform/platform/service-bus.tf)
