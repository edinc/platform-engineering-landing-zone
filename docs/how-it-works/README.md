# How it works

These guides explain how each platform capability works end to end — the flow,
not just an inventory of resources. Read them alongside the
[architecture reference](../architecture/README.md), which shows how the
capabilities fit together, and the [ADRs](../adr/README.md), which record why
each choice was made.

The capabilities build on each other in dependency order: foundation and
connectivity come before platform services; supply chain & CI/CD comes before
GitOps and the portal.

| Guide | What it covers |
| --- | --- |
| [Azure foundation](foundation.md) | Remote state, OIDC deployment identity, seed Key Vault, break-glass, and subscription baseline. |
| [Connectivity & egress](connectivity-egress.md) | Hub/spoke networking, Private DNS, default-deny FQDN allowlist, identity groups, and PIM. |
| [Platform shared services](platform-services.md) | Private AKS (CNI Overlay + Cilium), ACR, Key Vault, Postgres, ingress, and eventing. |
| [Supply chain & CI/CD](supply-chain-cicd.md) | Reusable workflows, OIDC federation, cosign keyless signing, SBOMs, scanning, and image promotion. |
| [GitOps platform](gitops.md) | Flux source of truth, the separate cluster-state repo, Kyverno admission, and the `platform-<profile>` source contract. |
| [Tenancy vending & onboarding](tenancy-vending-onboarding.md) | The end-to-end loop that vends subscriptions, teams, and namespaces. |
| [Golden paths](golden-paths.md) | The three software templates and what each scaffolds by default. |
| [Observability, SRE & FinOps](observability-sre-finops.md) | Telemetry, dashboards, SLOs, alerting, and the cost-showback pipeline. |
| [Developer portal](developer-portal.md) | Backstage: auth, catalog, TechDocs, plugins, RBAC, and scaffolding. |
| [Reliability operations](reliability-operations.md) | DR drills, incident workflow, status page, and post-mortems. |
| [Security & compliance](security-compliance.md) | Inherited policy baseline, Defender, required tags, Kyverno, and secrets. |
