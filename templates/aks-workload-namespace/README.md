# AKS workload namespace template

Opens the namespace vending request that application teams need before
they can deploy AKS microservices.

The template collects team/product/environment ownership inputs plus an explicit
DNS-safe namespace, maps the quota tier to concrete Kubernetes `ResourceQuota`
values, adds the immutable Entra group object ID, and opens a reviewed PR
containing:

- a `NamespaceVendingRequest` under `vending/requests/namespaces/`;
- a Backstage `Resource` entity for ownership, cost, and on-call tracking;
- platform and security reviewer hints for the PR.
