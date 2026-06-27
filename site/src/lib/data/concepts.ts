/**
 * Core platform-engineering concepts, each paired with how THIS project realises
 * it and a link to the proof in the repository. Content distilled from
 * docs/architecture and docs/how-it-works; proof paths are repo-relative.
 */
export type ProofKind = "guide" | "adr" | "code";

export interface Proof {
  label: string;
  path: string;
  kind: ProofKind;
}

export interface Concept {
  id: string;
  icon: string;
  term: string;
  tag: string;
  idea: string;
  applied: string;
  proofs: Proof[];
}

export const concepts: Concept[] = [
  {
    id: "golden-paths",
    icon: "route",
    term: "Golden paths",
    tag: "paved roads",
    idea: "A golden path is the supported, well-lit way to build and run a service. It packages the platform's hard decisions into a default route so teams don't reinvent CI, security or delivery for every service.",
    applied:
      "Three Backstage templates (AKS microservice, ACA service, AKS workload namespace) scaffold a repo with CI, SBOMs, signing, GitOps, SLOs, dashboards, cost tags, TechDocs and ownership wired in from the first commit.",
    proofs: [
      { label: "how-it-works: golden paths", path: "docs/how-it-works/golden-paths.md", kind: "guide" },
      { label: "templates/", path: "templates", kind: "code" },
      { label: "ADR-0044 template versioning", path: "docs/adr/0044-template-versioning.md", kind: "adr" },
    ],
  },
  {
    id: "self-service",
    icon: "compass",
    term: "Self-service",
    tag: "reduce cognitive load",
    idea: "Developers should reach a running, governed service without filing tickets or learning the whole cloud. The platform is a product; paved roads are its features.",
    applied:
      "Teams consume golden paths through the Backstage portal and reach a running endpoint without touching the Azure portal. Vending turns a reviewed request into identity, RBAC, quota and a namespace automatically.",
    proofs: [
      { label: "how-it-works: developer portal", path: "docs/how-it-works/developer-portal.md", kind: "guide" },
      { label: "how-it-works: vending & onboarding", path: "docs/how-it-works/tenancy-vending-onboarding.md", kind: "guide" },
    ],
  },
  {
    id: "gitops",
    icon: "git-branch",
    term: "GitOps",
    tag: "Flux is the source of truth",
    idea: "Desired cluster state lives in Git and a controller continuously reconciles the cluster to match. Changes are reviewed pull requests; drift is corrected automatically.",
    applied:
      "Flux owns in-cluster state from a separate platform-cluster-state repository, so a bad cluster change can never take down the platform's Terraform state. Vended teams receive manifests there; merge triggers reconciliation.",
    proofs: [
      { label: "how-it-works: GitOps", path: "docs/how-it-works/gitops.md", kind: "guide" },
      { label: "platform-gitops/", path: "platform-gitops", kind: "code" },
      { label: "ADR-0054 Flux Workload Identity", path: "docs/adr/0054-flux-controller-workload-identity-migration.md", kind: "adr" },
    ],
  },
  {
    id: "policy-as-code",
    icon: "scale",
    term: "Policy as code",
    tag: "guardrails, not gates",
    idea: "Governance is expressed as version-controlled, testable policy at three honest layers: the cloud control plane, infrastructure plan-time, and the cluster admission path.",
    applied:
      "Azure Policy governs the Azure control plane, OPA/Rego via conftest validates Terraform plans, and Kyverno is the single in-cluster admission and mutation engine. The Gatekeeper add-on is intentionally not used.",
    proofs: [
      { label: "how-it-works: security & compliance", path: "docs/how-it-works/security-compliance.md", kind: "guide" },
      { label: "policies/", path: "policies", kind: "code" },
      { label: "ADR-0036 Kyverno single engine", path: "docs/adr/0036-kyverno-single-engine.md", kind: "adr" },
    ],
  },
  {
    id: "secure-by-default",
    icon: "shield",
    term: "Secure by default",
    tag: "private, least-privilege",
    idea: "Security is the baseline every environment inherits, not an add-on. The safe choice is the default choice, and relaxing it is a deliberate, reviewed exception.",
    applied:
      "Private AKS API server, Workload Identity, Azure CNI Overlay with Cilium, default-deny egress through the hub firewall, Private Link for Key Vault, ACR and Postgres, and Kyverno-verified signed images. Even demo relaxes cost SKUs, never the security model.",
    proofs: [
      { label: "how-it-works: connectivity & egress", path: "docs/how-it-works/connectivity-egress.md", kind: "guide" },
      { label: "ADR-0031 default-deny egress", path: "docs/adr/0031-default-deny-egress.md", kind: "adr" },
      { label: "ADR-0025 OIDC federation", path: "docs/adr/0025-oidc-federation.md", kind: "adr" },
    ],
  },
  {
    id: "supply-chain",
    icon: "shield-check",
    term: "Supply-chain integrity",
    tag: "signed & scanned",
    idea: "An artifact should be traceable to its source and verified before it runs. Identity replaces stored secrets; signatures and SBOMs make provenance checkable.",
    applied:
      "GitHub authenticates to Azure with OIDC federation (no static cloud secrets). Images are signed with cosign keyless, SBOMs and vulnerability scans gate releases, and Kyverno refuses unsigned images at admission.",
    proofs: [
      { label: "how-it-works: supply chain & CI/CD", path: "docs/how-it-works/supply-chain-cicd.md", kind: "guide" },
      { label: "ADR-0007 image signing", path: "docs/adr/0007-image-signing.md", kind: "adr" },
      { label: "workflows/", path: "workflows", kind: "code" },
    ],
  },
  {
    id: "ownership",
    icon: "boxes",
    term: "Ownership boundaries",
    tag: "one owner per layer",
    idea: "Every layer of desired state has exactly one owner. Clear boundaries keep blast radius small and stop two systems fighting over the same resource.",
    applied:
      "The enterprise ALZ owns management groups and tenant policy. Terraform owns subscription and platform infrastructure. Flux owns Kubernetes state. Azure Service Operator owns workload Azure dependencies. Backstage only initiates; it is never a source of truth.",
    proofs: [
      { label: "architecture: ownership boundaries", path: "docs/architecture/README.md", kind: "guide" },
      { label: "ADR-0005 ASO boundary", path: "docs/adr/0005-aso-boundary.md", kind: "adr" },
      { label: "ADR-0043 ownership matrix", path: "docs/adr/0043-ownership-matrix.md", kind: "adr" },
    ],
  },
  {
    id: "finops",
    icon: "coins",
    term: "FinOps & showback",
    tag: "cost is a first-class signal",
    idea: "Teams can only manage spend they can see. Cost is allocated to the team and product that incurred it and surfaced where engineers already work.",
    applied:
      "Mandatory tags (owner, product, costCenter, env) flow from Cost Management exports through an allocator into a showback pipeline, surfaced per team and product in Backstage Cost Insights.",
    proofs: [
      { label: "how-it-works: observability, SRE & FinOps", path: "docs/how-it-works/observability-sre-finops.md", kind: "guide" },
      { label: "ADR-0057 cost allocator", path: "docs/adr/0057-cost-allocator-aad-onedeploy.md", kind: "adr" },
    ],
  },
];
