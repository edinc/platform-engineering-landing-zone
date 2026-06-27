# ADR-0037: OTel resource attributes and log fields

- Status: accepted
- Date: 2026-06-12
- Capability: observability, SRE & FinOps

## Context

Golden paths need consistent telemetry before templates ship. Without a shared
resource-attribute and log-field contract, dashboards, SLOs, cost allocation,
and Backstage observability plugins would need per-service customization.

## Decision

Standardize on OpenTelemetry resource attributes `service.name`,
`service.namespace`, `team`, `product`, `deployment.environment`, and `version`.
Structured logs must be JSON and include trace correlation fields plus the same
ownership and product fields. Golden paths reference Pino for Node.js, structlog
for Python, and Serilog for .NET.

The platform OTel collector enriches Kubernetes telemetry from namespace and pod
labels, adds environment metadata through Flux substitutions, keeps 100 percent
sampling for demo/dev, and applies a 10 percent baseline with error-priority tail
sampling for production-like profiles.

## Consequences

- Dashboard, SLO, alert, and cost views can aggregate by team and product.
- Workloads must set the standard Kubernetes labels that feed OTel enrichment.
- Production trace volume is bounded while errors remain preferentially retained.
- Golden path templates must not introduce service-specific telemetry field names.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Per-language conventions only | Produces inconsistent dimensions and breaks shared dashboards. |
| ECS only | Useful for log field naming, but does not cover OTel resource attributes or traces. |
| Collect everything at 100 percent | Too expensive for nonprod/prod and unnecessary for platform SLOs. |

## References

- [`platform-gitops/clusters/_base/addon-config/observability/otel-conventions-configmap.yaml`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/platform-gitops/clusters/_base/addon-config/observability/otel-conventions-configmap.yaml)
- [`platform-gitops/clusters/_base/controllers/platform/opentelemetry-collector.yaml`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/platform-gitops/clusters/_base/controllers/platform/opentelemetry-collector.yaml)
- [observability, SRE & FinOps](../how-it-works/observability-sre-finops.md)
