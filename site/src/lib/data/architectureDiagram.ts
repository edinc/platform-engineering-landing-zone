/** Component model + fixed layout for the interactive architecture diagram.
 *  Coordinates are in a 1000x660 SVG space. Detail is distilled from
 *  docs/architecture and docs/how-it-works; proofs are repo-relative. */
import { owners, type Owner } from "./architecture";

export { owners };
export type { Owner };

export interface DiagramGroup {
  id: string;
  label: string;
  x: number;
  y: number;
  w: number;
  h: number;
  kind: "subscription" | "cluster" | "hub" | "workloads";
  logo?: string;
}

export interface DiagramNode {
  id: string;
  label: string;
  sub: string;
  logo: string;
  owner: keyof typeof owners;
  x: number;
  y: number;
  w: number;
  h: number;
  bar?: boolean;
  summary: string;
  why: string;
  proofs: { label: string; path: string; kind: "guide" | "adr" | "code" }[];
}

export interface DiagramEdge {
  from: string;
  to: string;
  label: string;
  points: [number, number][];
  labelAt: [number, number];
  dashed?: boolean;
}

export const groups: DiagramGroup[] = [
  { id: "platform-sub", label: "Platform subscription", x: 40, y: 130, w: 920, h: 430, kind: "subscription" },
  { id: "hub", label: "Connectivity · hub", x: 62, y: 196, w: 188, h: 110, kind: "hub" },
  { id: "aks", label: "AKS · private (Cilium)", x: 286, y: 196, w: 430, h: 214, kind: "cluster", logo: "kubernetes" },
  { id: "workloads", label: "Workload landing zones", x: 62, y: 412, w: 876, h: 128, kind: "workloads" },
];

export const nodes: DiagramNode[] = [
  {
    id: "github",
    label: "GitHub",
    sub: "reusable workflows",
    logo: "github",
    owner: "github",
    x: 40,
    y: 34,
    w: 230,
    h: 72,
    summary: "Reusable CI/CD workflows build, scan, sign and attest every artifact.",
    why: "GitHub federates to Azure with OIDC, so there are no stored cloud secrets. Signatures and SBOMs make provenance checkable before anything runs.",
    proofs: [
      { label: "how-it-works: supply chain & CI/CD", path: "docs/how-it-works/supply-chain-cicd.md", kind: "guide" },
      { label: "ADR-0025 OIDC federation", path: "docs/adr/0025-oidc-federation.md", kind: "adr" },
    ],
  },
  {
    id: "firewall",
    label: "Firewall",
    sub: "default-deny egress",
    logo: "firewall",
    owner: "terraform",
    x: 78,
    y: 232,
    w: 164,
    h: 58,
    summary: "The hub firewall enforces default-deny egress with an FQDN allowlist; Private DNS resolves private endpoints.",
    why: "Outbound is blocked unless explicitly allowed, so a compromised workload cannot phone home. Additions go through a time-bound exception workflow.",
    proofs: [
      { label: "how-it-works: connectivity & egress", path: "docs/how-it-works/connectivity-egress.md", kind: "guide" },
      { label: "ADR-0031 default-deny egress", path: "docs/adr/0031-default-deny-egress.md", kind: "adr" },
    ],
  },
  {
    id: "flux",
    label: "Flux",
    sub: "GitOps",
    logo: "flux",
    owner: "flux",
    x: 304,
    y: 240,
    w: 188,
    h: 58,
    summary: "Flux reconciles the cluster to the desired state in a separate cluster-state repository.",
    why: "In-cluster state lives in its own repo, so a bad cluster change can never take down the platform's Terraform state. Every change is a reviewed pull request.",
    proofs: [
      { label: "how-it-works: GitOps", path: "docs/how-it-works/gitops.md", kind: "guide" },
      { label: "ADR-0054 Flux Workload Identity", path: "docs/adr/0054-flux-controller-workload-identity-migration.md", kind: "adr" },
    ],
  },
  {
    id: "kyverno",
    label: "Kyverno",
    sub: "admission",
    logo: "kyverno",
    owner: "flux",
    x: 508,
    y: 240,
    w: 188,
    h: 58,
    summary: "The single in-cluster admission and mutation engine. It verifies image signatures and enforces policy at admission.",
    why: "One policy engine keeps governance predictable; the Azure Policy Gatekeeper add-on is intentionally not used. Unsigned images are refused.",
    proofs: [
      { label: "how-it-works: security & compliance", path: "docs/how-it-works/security-compliance.md", kind: "guide" },
      { label: "ADR-0036 Kyverno single engine", path: "docs/adr/0036-kyverno-single-engine.md", kind: "adr" },
    ],
  },
  {
    id: "backstage",
    label: "Backstage",
    sub: "portal",
    logo: "backstage",
    owner: "flux",
    x: 304,
    y: 314,
    w: 188,
    h: 58,
    summary: "The developer portal: catalog, TechDocs and the golden-path scaffolder.",
    why: "Backstage initiates workflows and surfaces state, but is never a source of truth; the systems it triggers stay authoritative.",
    proofs: [
      { label: "how-it-works: developer portal", path: "docs/how-it-works/developer-portal.md", kind: "guide" },
      { label: "ADR-0041 Backstage RBAC", path: "docs/adr/0041-backstage-rbac.md", kind: "adr" },
    ],
  },
  {
    id: "observability",
    label: "Observability",
    sub: "dashboards · SLOs",
    logo: "grafana",
    owner: "flux",
    x: 508,
    y: 314,
    w: 188,
    h: 58,
    summary: "Managed Prometheus and Grafana with OpenTelemetry conventions feed dashboards, SLOs, alerting and cost.",
    why: "Shared telemetry dimensions let dashboards, SLOs, alerts and cost all key off the same owner, product and environment tags.",
    proofs: [
      { label: "how-it-works: observability, SRE & FinOps", path: "docs/how-it-works/observability-sre-finops.md", kind: "guide" },
      { label: "ADR-0037 OTel conventions", path: "docs/adr/0037-otel-conventions.md", kind: "adr" },
    ],
  },
  {
    id: "acr",
    label: "ACR",
    sub: "signed images",
    logo: "acr",
    owner: "terraform",
    x: 740,
    y: 196,
    w: 200,
    h: 58,
    summary: "Premium Azure Container Registry with geo-replication and a pull-through cache, behind Private Link.",
    why: "Images are pushed signed from CI and pulled privately by the cluster; Kyverno verifies the signature at admission.",
    proofs: [
      { label: "how-it-works: platform services", path: "docs/how-it-works/platform-services.md", kind: "guide" },
      { label: "ADR-0007 image signing", path: "docs/adr/0007-image-signing.md", kind: "adr" },
    ],
  },
  {
    id: "keyvault",
    label: "Key Vault",
    sub: "Private Link",
    logo: "keyvault",
    owner: "terraform",
    x: 740,
    y: 262,
    w: 200,
    h: 58,
    summary: "RBAC-secured Key Vault for secrets and certificates, reachable only over Private Link.",
    why: "Workloads read secrets via Workload Identity and the CSI/ESO providers, so no secret is copied into a pipeline or image.",
    proofs: [
      { label: "how-it-works: platform services", path: "docs/how-it-works/platform-services.md", kind: "guide" },
      { label: "ADR-0006 secrets in cluster", path: "docs/adr/0006-secrets-in-cluster.md", kind: "adr" },
    ],
  },
  {
    id: "postgres",
    label: "Postgres",
    sub: "HA · PITR",
    logo: "postgres",
    owner: "terraform",
    x: 740,
    y: 328,
    w: 200,
    h: 58,
    summary: "Azure Database for PostgreSQL Flexible Server, zone-redundant with point-in-time restore in prod.",
    why: "A managed, private, highly-available datastore the platform's own services (such as Backstage) depend on.",
    proofs: [
      { label: "how-it-works: platform services", path: "docs/how-it-works/platform-services.md", kind: "guide" },
      { label: "ADR-0052 Backstage Postgres", path: "docs/adr/0052-backstage-postgres-auth.md", kind: "adr" },
    ],
  },
  {
    id: "namespaces",
    label: "Vended namespaces",
    sub: "quota · NetworkPolicy · identity",
    logo: "namespaces",
    owner: "flux",
    x: 84,
    y: 452,
    w: 400,
    h: 74,
    summary: "Each team gets an isolated namespace with quota, default-deny networking, a bound identity and cost tags.",
    why: "Tenancy is request-as-code: a merged vending PR provisions a governed landing space without manual portal clicks.",
    proofs: [
      { label: "how-it-works: vending & onboarding", path: "docs/how-it-works/tenancy-vending-onboarding.md", kind: "guide" },
      { label: "ADR-0033 namespace vending", path: "docs/adr/0033-aks-namespace-vending.md", kind: "adr" },
    ],
  },
  {
    id: "aso",
    label: "Azure Service Operator",
    sub: "workload Azure deps",
    logo: "aso",
    owner: "aso",
    x: 516,
    y: 452,
    w: 400,
    h: 74,
    summary: "Lets workload teams declare their Azure dependencies as Kubernetes resources, reconciled into real Azure resources.",
    why: "Workload teams own their Azure deps from inside the cluster, without Terraform access to platform infrastructure. Clear ownership, small blast radius.",
    proofs: [
      { label: "architecture: ownership boundaries", path: "docs/architecture/README.md", kind: "guide" },
      { label: "ADR-0005 ASO boundary", path: "docs/adr/0005-aso-boundary.md", kind: "adr" },
    ],
  },
  {
    id: "monitor",
    label: "Azure Monitor · Defender · Cost Management",
    sub: "",
    logo: "shield",
    owner: "terraform",
    x: 40,
    y: 586,
    w: 920,
    h: 52,
    bar: true,
    summary: "Central diagnostics, Defender for Cloud posture and Cost Management exports across every onboarded subscription.",
    why: "The compliance baseline every profile inherits: activity logs, security posture and the tag-driven cost pipeline that powers showback.",
    proofs: [
      { label: "how-it-works: foundation", path: "docs/how-it-works/foundation.md", kind: "guide" },
      { label: "ADR-0011 compliance baseline", path: "docs/adr/0011-compliance-baseline.md", kind: "adr" },
    ],
  },
];

export const edges: DiagramEdge[] = [
  {
    from: "github",
    to: "acr",
    label: "signed images",
    points: [
      [270, 70],
      [840, 70],
      [840, 196],
    ],
    labelAt: [556, 60],
  },
  {
    from: "github",
    to: "flux",
    label: "OIDC · no secrets",
    points: [
      [150, 106],
      [150, 168],
      [398, 168],
      [398, 240],
    ],
    labelAt: [330, 160],
  },
  {
    from: "firewall",
    to: "flux",
    label: "egress",
    points: [
      [242, 261],
      [273, 261],
      [273, 269],
      [304, 269],
    ],
    labelAt: [268, 252],
  },
  {
    from: "flux",
    to: "namespaces",
    label: "reconcile",
    points: [
      [304, 282],
      [268, 282],
      [268, 430],
      [180, 430],
      [180, 452],
    ],
    labelAt: [214, 366],
  },
  {
    from: "keyvault",
    to: "aso",
    label: "Workload Identity",
    points: [
      [940, 291],
      [970, 291],
      [970, 489],
      [916, 489],
    ],
    labelAt: [905, 408],
    dashed: true,
  },
  {
    from: "platform-sub",
    to: "monitor",
    label: "diagnostics",
    points: [
      [500, 560],
      [500, 586],
    ],
    labelAt: [548, 576],
    dashed: true,
  },
];
