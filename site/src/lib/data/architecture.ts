/** Layered capability model for the interactive Architecture Explorer.
 *  Sourced from docs/architecture/README.md (layers, ownership, profiles). */

export interface Owner {
  id: string;
  label: string;
  /** css var for the categorical fill + its AA-on-white ink variant */
  fill: string;
  ink: string;
}

export const owners: Record<string, Owner> = {
  alz: { id: "alz", label: "Enterprise ALZ", fill: "var(--faint)", ink: "var(--muted)" },
  terraform: { id: "terraform", label: "Terraform", fill: "var(--cat-1)", ink: "var(--cat-1-ink)" },
  github: { id: "github", label: "GitHub Actions", fill: "var(--cat-6)", ink: "var(--cat-6-ink)" },
  flux: { id: "flux", label: "Flux", fill: "var(--cat-4)", ink: "var(--cat-4-ink)" },
  aso: { id: "aso", label: "Azure Service Operator", fill: "var(--cat-3)", ink: "var(--cat-3-ink)" },
  backstage: { id: "backstage", label: "Backstage", fill: "var(--cat-7)", ink: "var(--cat-7-ink)" },
};

export interface Layer {
  id: string;
  level: string;
  name: string;
  owner: keyof typeof owners;
  tech: string[];
  summary: string;
  why: string;
  proofs: { label: string; path: string; kind: "guide" | "adr" | "code" }[];
}

/** Ordered bottom (L0) to top (L10); the explorer renders top-down. */
export const layers: Layer[] = [
  {
    id: "tenant-identity",
    level: "L0",
    name: "Tenant & identity",
    owner: "alz",
    tech: ["Entra ID", "PIM", "Platform groups", "Break-glass"],
    summary:
      "The Entra tenant, privileged-access model and platform groups the whole platform builds on.",
    why: "Identity is the real perimeter. Just-in-time privileged access and audited break-glass keep standing admin rights close to zero.",
    proofs: [
      { label: "how-it-works: foundation", path: "docs/how-it-works/foundation.md", kind: "guide" },
      { label: "ADR-0024 break-glass", path: "docs/adr/0024-break-glass.md", kind: "adr" },
    ],
  },
  {
    id: "subscription-baseline",
    level: "L1",
    name: "Subscription baseline",
    owner: "terraform",
    tech: ["Activity Logs", "Defender for Cloud", "Budgets", "Cost exports", "Required tags"],
    summary:
      "What every onboarded subscription inherits: diagnostics, security posture, budgets and the mandatory tag set.",
    why: "A consistent baseline means no subscription is a snowflake; compliance and cost visibility are present from day zero.",
    proofs: [
      { label: "how-it-works: foundation", path: "docs/how-it-works/foundation.md", kind: "guide" },
      { label: "ADR-0011 compliance baseline", path: "docs/adr/0011-compliance-baseline.md", kind: "adr" },
    ],
  },
  {
    id: "connectivity",
    level: "L2",
    name: "Connectivity & egress",
    owner: "terraform",
    tech: ["Hub VNet", "Azure Firewall Premium", "Private DNS", "Private Link", "FQDN allowlist"],
    summary:
      "Hub-and-spoke networking with private resolution and default-deny egress through the hub firewall.",
    why: "Outbound is denied unless explicitly allowed, so a compromised workload cannot phone home. Exceptions are time-bound and reviewed.",
    proofs: [
      { label: "how-it-works: connectivity & egress", path: "docs/how-it-works/connectivity-egress.md", kind: "guide" },
      { label: "ADR-0031 default-deny egress", path: "docs/adr/0031-default-deny-egress.md", kind: "adr" },
      { label: "ADR-0030 hub & spoke", path: "docs/adr/0030-hub-and-spoke.md", kind: "adr" },
    ],
  },
  {
    id: "shared-services",
    level: "L3",
    name: "Platform shared services",
    owner: "terraform",
    tech: ["Private AKS", "Cilium", "ACR", "Key Vault", "Postgres", "ingress"],
    summary:
      "The private AKS cluster, registry, secrets and database that every workload shares, all behind Private Link.",
    why: "Shared, hardened services mean teams inherit a secure substrate instead of standing up (and securing) their own.",
    proofs: [
      { label: "how-it-works: platform services", path: "docs/how-it-works/platform-services.md", kind: "guide" },
      { label: "ADR-0026 AVM modules", path: "docs/adr/0026-avm-modules.md", kind: "adr" },
    ],
  },
  {
    id: "in-cluster",
    level: "L4",
    name: "In-cluster platform",
    owner: "flux",
    tech: ["Flux", "Kyverno", "cert-manager", "external-dns", "ESO / CSI", "Prometheus"],
    summary:
      "The GitOps-managed controllers and admission policy that make the cluster a platform, reconciled by Flux.",
    why: "Flux owns in-cluster state from a separate repo, so a bad cluster change can never corrupt the platform's Terraform state.",
    proofs: [
      { label: "how-it-works: GitOps", path: "docs/how-it-works/gitops.md", kind: "guide" },
      { label: "ADR-0036 Kyverno single engine", path: "docs/adr/0036-kyverno-single-engine.md", kind: "adr" },
    ],
  },
  {
    id: "supply-chain",
    level: "L5",
    name: "Supply chain & CI/CD",
    owner: "github",
    tech: ["Reusable workflows", "OIDC federation", "cosign keyless", "SBOM", "Scanning"],
    summary:
      "Reusable GitHub workflows that build, scan, sign and attest artifacts using OIDC instead of stored secrets.",
    why: "Provenance is checkable: signed images and SBOMs gate releases, and Kyverno refuses anything unsigned at admission.",
    proofs: [
      { label: "how-it-works: supply chain & CI/CD", path: "docs/how-it-works/supply-chain-cicd.md", kind: "guide" },
      { label: "ADR-0007 image signing", path: "docs/adr/0007-image-signing.md", kind: "adr" },
      { label: "ADR-0025 OIDC federation", path: "docs/adr/0025-oidc-federation.md", kind: "adr" },
    ],
  },
  {
    id: "observability",
    level: "L6",
    name: "Observability, SRE & FinOps",
    owner: "flux",
    tech: ["OpenTelemetry", "Managed Grafana", "SLO toolkit", "Alert routing", "Cost allocation"],
    summary:
      "Telemetry conventions, dashboards, SLOs and the cost-allocation pipeline that turn signals into operability and showback.",
    why: "Shared telemetry dimensions let dashboards, SLOs, alerting and cost all key off the same owner, product and environment tags.",
    proofs: [
      { label: "how-it-works: observability, SRE & FinOps", path: "docs/how-it-works/observability-sre-finops.md", kind: "guide" },
      { label: "ADR-0037 OTel conventions", path: "docs/adr/0037-otel-conventions.md", kind: "adr" },
    ],
  },
  {
    id: "portal",
    level: "L7",
    name: "Developer portal",
    owner: "flux",
    tech: ["Backstage", "Entra auth", "Catalog", "TechDocs", "Scaffolder", "RBAC"],
    summary:
      "Backstage: the front door where developers discover services, read docs and launch golden paths.",
    why: "The portal initiates workflows and surfaces state, but is never a source of truth; the systems it triggers remain authoritative.",
    proofs: [
      { label: "how-it-works: developer portal", path: "docs/how-it-works/developer-portal.md", kind: "guide" },
      { label: "ADR-0041 Backstage RBAC", path: "docs/adr/0041-backstage-rbac.md", kind: "adr" },
    ],
  },
  {
    id: "tenancy",
    level: "L8",
    name: "Multi-tenancy & onboarding",
    owner: "terraform",
    tech: ["Namespace vending", "Team onboarding", "ResourceQuota", "Ownership matrix", "Showback"],
    summary:
      "The loop that vends teams and namespaces with identity, quota, RBAC and cost tags from a reviewed request.",
    why: "Tenancy is request-as-code: a merged vending PR provisions an isolated, governed landing space without manual portal clicks.",
    proofs: [
      { label: "how-it-works: vending & onboarding", path: "docs/how-it-works/tenancy-vending-onboarding.md", kind: "guide" },
      { label: "ADR-0033 namespace vending", path: "docs/adr/0033-aks-namespace-vending.md", kind: "adr" },
    ],
  },
  {
    id: "golden-paths",
    level: "L9",
    name: "Golden paths",
    owner: "backstage",
    tech: ["AKS microservice", "ACA service", "AKS namespace", "CI + SBOM + signing", "TechDocs"],
    summary:
      "Three Backstage templates that scaffold a production-ready repo with everything wired in from commit one.",
    why: "Golden paths are the productized entry point: they call the platform's capabilities with safe defaults and reviewed outputs.",
    proofs: [
      { label: "how-it-works: golden paths", path: "docs/how-it-works/golden-paths.md", kind: "guide" },
      { label: "ADR-0044 template versioning", path: "docs/adr/0044-template-versioning.md", kind: "adr" },
    ],
  },
  {
    id: "reliability",
    level: "L10",
    name: "Reliability operations",
    owner: "flux",
    tech: ["DR drills", "Status page", "Incident workflow", "Post-mortems", "Runbooks"],
    summary:
      "The day-2 practices that keep the platform dependable: drills, incident response and a public status surface.",
    why: "A platform is only as good as its operability; rehearsed recovery and blameless post-mortems make reliability a habit, not a hope.",
    proofs: [
      { label: "how-it-works: reliability operations", path: "docs/how-it-works/reliability-operations.md", kind: "guide" },
      { label: "runbooks", path: "docs/runbooks/README.md", kind: "guide" },
    ],
  },
];
