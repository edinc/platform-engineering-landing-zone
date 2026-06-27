/** Personas and their journeys. `concepts` maps to ids in concepts.ts so a
 *  selected persona can highlight the relevant concept rows across the page. */
export interface Persona {
  id: string;
  label: string;
  role: string;
  icon: string;
  value: string;
  concepts: string[];
  journey: { title: string; detail: string }[];
}

export const personas: Persona[] = [
  {
    id: "developer",
    label: "Application developer",
    role: "ships a service",
    icon: "terminal",
    value: "Reach a running, governed service without learning the whole cloud.",
    concepts: ["golden-paths", "self-service", "supply-chain", "gitops"],
    journey: [
      { title: "Pick a golden path", detail: "Open Backstage and choose the AKS microservice template." },
      { title: "Describe the service", detail: "Ownership, product, cost centre, runtime and scaling, with safe defaults." },
      { title: "Get a wired-up repo", detail: "CI, cosign signing, SBOMs, Helm chart, SLOs and TechDocs from commit one." },
      { title: "Push to main", detail: "The image is built, scanned and signed; a GitOps PR opens automatically." },
      { title: "Merge and run", detail: "Flux deploys into your namespace; dashboards and SLOs are already live." },
    ],
  },
  {
    id: "platform-engineer",
    label: "Platform engineer",
    role: "runs the platform",
    icon: "cpu",
    value: "An opinionated reference IDP, with the decisions behind every layer.",
    concepts: ["gitops", "policy-as-code", "secure-by-default", "ownership", "supply-chain"],
    journey: [
      { title: "Onboard a subscription", detail: "Terraform applies the baseline: diagnostics, Defender, budgets, tags." },
      { title: "Stand up shared services", detail: "Private AKS with Cilium, ACR, Key Vault and Postgres behind Private Link." },
      { title: "Let Flux reconcile", detail: "Add-ons, controllers and policy flow from the separate cluster-state repo." },
      { title: "Author guardrails", detail: "Kyverno admission policy and versioned golden-path templates." },
      { title: "Review, don't operate", detail: "Approve vending PRs; Terraform and Flux stay the source of truth." },
    ],
  },
  {
    id: "leader",
    label: "Engineering leader & FinOps",
    role: "owns outcomes",
    icon: "coins",
    value: "Faster delivery, guardrails by default, and cost you can actually see.",
    concepts: ["self-service", "finops", "secure-by-default", "ownership"],
    journey: [
      { title: "Self-service throughput", detail: "Paved roads remove ticket queues; teams deliver without bottlenecks." },
      { title: "Risk reduced by default", detail: "Policy, signing and default-deny egress are inherited, not optional." },
      { title: "Every cost has an owner", detail: "Mandatory tags allocate spend to the team and product that incurred it." },
      { title: "Showback where they work", detail: "Cost Insights surfaces per-team, per-product spend inside Backstage." },
      { title: "Audit-ready baseline", detail: "Inherited CIS/ALZ compliance posture across every onboarded subscription." },
    ],
  },
  {
    id: "curious",
    label: "Platform-curious",
    role: "wants the why",
    icon: "compass",
    value: "Understand what an Internal Developer Platform is, and why it matters.",
    concepts: ["golden-paths", "self-service", "gitops", "finops"],
    journey: [
      { title: "What is an IDP?", detail: "A product that paves a supported road from code to production." },
      { title: "Golden paths", detail: "They remove undifferentiated toil so teams focus on their product." },
      { title: "GitOps", detail: "Everything is a reviewed pull request, continuously reconciled." },
      { title: "Secure & signed", detail: "Private by default, with a verified, signed software supply chain." },
      { title: "Made concrete", detail: "See each idea realised in a real, opinionated Azure platform." },
    ],
  },
];
