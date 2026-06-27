/** The life of a request along a golden path, end to end. Each step exposes the
 *  real artifact it produces. Snippets are illustrative / representative. */
export interface Actor {
  id: string;
  label: string;
  fill: string;
}

export const actors: Record<string, Actor> = {
  developer: { id: "developer", label: "Developer", fill: "var(--cat-7)" },
  backstage: { id: "backstage", label: "Backstage", fill: "var(--cat-7)" },
  platform: { id: "platform", label: "Platform repo", fill: "var(--cat-1)" },
  github: { id: "github", label: "GitHub Actions", fill: "var(--cat-6)" },
  terraform: { id: "terraform", label: "Terraform", fill: "var(--cat-1)" },
  flux: { id: "flux", label: "Flux", fill: "var(--cat-4)" },
  azure: { id: "azure", label: "Azure", fill: "var(--cat-2)" },
};

export interface Step {
  n: number;
  title: string;
  actor: keyof typeof actors;
  summary: string;
  artifact: { name: string; lang: string; code: string };
}

export const steps: Step[] = [
  {
    n: 1,
    title: "Request a paved road",
    actor: "developer",
    summary:
      "A developer opens the Backstage portal and picks a golden-path template, then describes the service: ownership, product, cost centre, environment and runtime.",
    artifact: {
      name: "Backstage template input",
      lang: "yaml",
      code: `team: payments
product: checkout
environment: nonprod
namespace: checkout
quotaTier: small
costCenter: cc-12345
dataClassification: confidential
onCall: payments-primary`,
    },
  },
  {
    n: 2,
    title: "Reviewed PR, as code",
    actor: "backstage",
    summary:
      "Backstage checks template permissions through platform RBAC, renders the request as code, and opens a pull request in the platform repository. Nothing is provisioned yet.",
    artifact: {
      name: "vending/requests/namespaces/checkout.yaml",
      lang: "yaml",
      code: `apiVersion: platform.local/v1
kind: NamespaceVendingRequest
metadata:
  name: payments-checkout-nonprod
spec:
  team: payments
  product: checkout
  quotaTier: small
  entraGroupObjectId: 00000000-…   # representative
  dataClassification: confidential`,
    },
  },
  {
    n: 3,
    title: "Plan-time guardrails",
    actor: "github",
    summary:
      "The PR runs reusable checks before a human looks: OPA/Rego via conftest validates the request and the Terraform plan, and required tags and ownership are enforced.",
    artifact: {
      name: "conftest (OPA/Rego) policy gate",
      lang: "text",
      code: `$ conftest test plan.json
PASS - required tags present (owner, product, costCenter, env)
PASS - quotaTier within allowed set
PASS - dataClassification is a known value
3 tests, 3 passed, 0 failed`,
    },
  },
  {
    n: 4,
    title: "Platform & security review",
    actor: "platform",
    summary:
      "Platform and security reviewers inspect the generated request. Merge, not authorship, is the trigger: only a reviewed, merged PR provisions anything.",
    artifact: {
      name: "Pull request checks",
      lang: "text",
      code: `✓ conftest / policy            passed
✓ terraform / plan             passed
✓ reviewers: @platform @sec    approved
→ merge triggers vending workflow`,
    },
  },
  {
    n: 5,
    title: "Terraform provisions identity",
    actor: "terraform",
    summary:
      "Merge triggers GitHub Actions and Terraform to create the tenancy primitives: a workload identity, scoped role assignments and the namespace's Azure-side bindings.",
    artifact: {
      name: "identity.tf",
      lang: "hcl",
      code: `resource "azurerm_role_assignment" "ns" {
  scope                = var.platform_aks_id
  role_definition_name = "Azure Kubernetes Service RBAC Writer"
  principal_id         = var.entra_group_object_id
  description          = "payments/checkout — nonprod"
}`,
    },
  },
  {
    n: 6,
    title: "Cluster-state PR",
    actor: "github",
    summary:
      "The workflow opens a pull request in the separate platform-cluster-state repository with the namespace's desired Kubernetes state. Flux watches that repo, not this one.",
    artifact: {
      name: "platform-cluster-state · namespace.yaml",
      lang: "yaml",
      code: `apiVersion: v1
kind: Namespace
metadata:
  name: payments-checkout
  labels:
    owner: payments
    product: checkout
    managedBy: flux`,
    },
  },
  {
    n: 7,
    title: "Flux reconciles",
    actor: "flux",
    summary:
      "After the cluster-state PR merges, Flux pulls the desired state and reconciles the cluster. Kyverno admits the resources, applying quota, network policy and a service account.",
    artifact: {
      name: "ResourceQuota + admission",
      lang: "yaml",
      code: `apiVersion: v1
kind: ResourceQuota
metadata: { name: small, namespace: payments-checkout }
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 4Gi
    pods: "20"
# Kyverno: default-deny NetworkPolicy + signed-image rule applied`,
    },
  },
  {
    n: 8,
    title: "Running & governed",
    actor: "azure",
    summary:
      "The team has an isolated, governed namespace: quota, default-deny networking, a bound identity, cost tags, dashboards and SLOs, ready for the first signed workload.",
    artifact: {
      name: "kubectl describe ns payments-checkout",
      lang: "text",
      code: `Name:         payments-checkout
Status:       Active
Labels:       owner=payments product=checkout managedBy=flux
Quota:        small (cpu 2 / mem 4Gi / pods 20)
NetworkPolicy: default-deny (egress via hub)
Identity:     workload-identity bound · signed images enforced`,
    },
  },
];
