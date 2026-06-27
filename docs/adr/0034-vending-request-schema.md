# ADR-0034: Vending request schema

- Status: accepted
- Date: 2026-06-11
- Capability: tenancy vending

## Context

Backstage, GitHub Actions, Terraform, and later platform APIs need a stable
contract for vending requests. Without an explicit schema, workflows would parse
ad hoc YAML and drift from Backstage templates or future API versions.

## Decision

**The vending request is the platform's first public contract and is versioned by
`apiVersion`.**

1. The tenancy vending capability supports `platform.example.io/v1alpha1`.
2. The JSON Schema lives at `docs/contracts/vending-request.schema.json`.
3. YAML examples live under `docs/contracts/` and are validated with
   `ajv-cli` in CI via `make contract-test`.
4. The schema separates `SubscriptionVendingRequest` and
   `NamespaceVendingRequest` while sharing team, product, cost, ownership,
   region, and tag fields.

## Consequences

- Backstage scaffolder templates in later capabilities can call the same workflow
  contract instead of inventing a portal-only API.
- Breaking changes require a new `apiVersion` and compatibility tests.
- The v1alpha1 schema rejects future v1-only fields so callers cannot rely on
  unimplemented behavior.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Free-form workflow inputs | Too easy to drift and difficult to validate in PRs. |
| Terraform variables as the only contract | Couples Backstage/API callers to implementation-specific stack inputs. |
| OpenAPI first | Useful later, but tenancy vending's executable surface is YAML requests in GitHub PRs. |

## References

- [`docs/contracts/vending-request.schema.json`](../contracts/vending-request.schema.json)
- [`docs/contracts/vending-request.yaml`](../contracts/vending-request.yaml)
- [`Makefile`](https://github.com/edinc/platform-engineering-landing-zone/blob/main/Makefile)
