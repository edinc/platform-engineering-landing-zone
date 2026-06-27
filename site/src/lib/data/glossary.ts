/** Linkable glossary terms. `see` points at concept anchors on the home page. */
export interface Term {
  id: string;
  term: string;
  def: string;
  see?: string; // concept id on the home page
}

export const terms: Term[] = [
  {
    id: "idp",
    term: "Internal Developer Platform (IDP)",
    def: "A product, built by a platform team, that gives application teams a self-service, paved road to production. It abstracts the cloud's complexity behind golden paths.",
    see: "self-service",
  },
  {
    id: "paved-road",
    term: "Paved road / golden path",
    def: "The supported, well-lit default way to build and run a service. It packages the platform's hard decisions so teams don't reinvent CI, security or delivery.",
    see: "golden-paths",
  },
  {
    id: "cognitive-load",
    term: "Cognitive load",
    def: "The total a team must hold in their heads to do their work. Platform engineering deliberately reduces extraneous load by absorbing undifferentiated cloud toil.",
  },
  {
    id: "enabling-team",
    term: "Enabling team",
    def: "A Team Topologies concept: a team that helps others get better at something rather than doing it for them. The platform team runs the IDP as a product.",
  },
  {
    id: "gitops",
    term: "GitOps",
    def: "An operating model where desired system state lives in Git and a controller continuously reconciles the running system to match. Changes are reviewed pull requests.",
    see: "gitops",
  },
  {
    id: "flux",
    term: "Flux",
    def: "A CNCF GitOps controller. Here it owns in-cluster Kubernetes state, reconciling the cluster from a separate cluster-state repository.",
    see: "gitops",
  },
  {
    id: "policy-as-code",
    term: "Policy as code",
    def: "Governance expressed as version-controlled, testable rules rather than wiki pages. Applied at the cloud control plane, at plan time, and at cluster admission.",
    see: "policy-as-code",
  },
  {
    id: "kyverno",
    term: "Kyverno",
    def: "A Kubernetes-native policy engine. It is the single in-cluster admission and mutation engine here; the Azure Policy Gatekeeper add-on is intentionally not used.",
    see: "policy-as-code",
  },
  {
    id: "opa-conftest",
    term: "OPA / conftest",
    def: "Open Policy Agent and its testing tool conftest, used to validate Terraform plans against Rego policy before any infrastructure changes are applied.",
    see: "policy-as-code",
  },
  {
    id: "workload-identity",
    term: "Workload Identity",
    def: "Lets a Kubernetes workload federate to an Entra identity and obtain Azure tokens without any stored secret, replacing long-lived credentials.",
    see: "secure-by-default",
  },
  {
    id: "oidc-federation",
    term: "OIDC federation",
    def: "Lets GitHub Actions authenticate to Azure using short-lived, workflow-scoped tokens instead of stored cloud secrets. Identity over secrets.",
    see: "supply-chain",
  },
  {
    id: "default-deny-egress",
    term: "Default-deny egress",
    def: "Outbound traffic is blocked unless explicitly allowed through the hub firewall's FQDN allowlist. Additions go through a time-bound exception workflow.",
    see: "secure-by-default",
  },
  {
    id: "private-link",
    term: "Private Link",
    def: "Keeps traffic to Azure PaaS services (Key Vault, ACR, Postgres) on the private network via private endpoints, instead of traversing public endpoints.",
    see: "secure-by-default",
  },
  {
    id: "cilium",
    term: "Azure CNI Overlay + Cilium",
    def: "The cluster networking and eBPF dataplane. Provides pod networking, network policy enforcement and observability for AKS.",
  },
  {
    id: "sbom",
    term: "SBOM",
    def: "A Software Bill of Materials: a machine-readable inventory of everything in an artifact. Generated for every build (SPDX and CycloneDX) to make dependencies auditable.",
    see: "supply-chain",
  },
  {
    id: "cosign",
    term: "cosign keyless signing",
    def: "Signs container images and Helm charts using short-lived certificates tied to an OIDC identity, with no long-lived signing key to manage or leak.",
    see: "supply-chain",
  },
  {
    id: "showback",
    term: "Showback",
    def: "Reporting each team's and product's cloud cost back to them for visibility, without necessarily charging it (chargeback). Driven by mandatory cost tags.",
    see: "finops",
  },
  {
    id: "finops",
    term: "FinOps",
    def: "The practice of bringing financial accountability to variable cloud spend, making cost a shared, engineering-visible signal rather than an afterthought.",
    see: "finops",
  },
  {
    id: "vending",
    term: "Vending",
    def: "Turning a reviewed, code-based request into provisioned tenancy: a subscription, team or namespace with identity, RBAC, quota and tags created automatically.",
    see: "self-service",
  },
  {
    id: "aso",
    term: "Azure Service Operator (ASO)",
    def: "A Kubernetes operator that lets workload teams declare their Azure dependencies as Kubernetes resources, reconciled into real Azure resources.",
    see: "ownership",
  },
  {
    id: "alz",
    term: "Azure Landing Zone (ALZ)",
    def: "The enterprise foundation that owns the management-group hierarchy and tenant-wide policy. This platform onboards subscriptions beneath an existing ALZ.",
    see: "ownership",
  },
  {
    id: "backstage",
    term: "Backstage",
    def: "An open developer portal. Here it provides the catalog, TechDocs and golden-path scaffolder. It initiates workflows but is never a source of truth.",
    see: "self-service",
  },
  {
    id: "psa",
    term: "Pod Security Admission (PSA)",
    def: "A built-in Kubernetes admission controller that enforces the Pod Security Standards, restricting what workloads are allowed to do at the pod level.",
    see: "secure-by-default",
  },
  {
    id: "break-glass",
    term: "Break-glass",
    def: "Tightly controlled, heavily audited emergency access used only when normal privileged-access paths are unavailable. Monitored and alerted on every use.",
  },
  {
    id: "pim",
    term: "PIM (Privileged Identity Management)",
    def: "Entra capability for just-in-time, time-bound, approved elevation to privileged roles, so standing administrative access stays close to zero.",
  },
  {
    id: "slo",
    term: "SLO",
    def: "A Service Level Objective: a target for a reliability signal (such as availability or latency) that a team commits to and measures against an error budget.",
  },
];
