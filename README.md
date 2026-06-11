# Platform Engineering Landing Zone

Opinionated Azure Platform Engineering Landing Zone for building a secure,
compliant, reusable Internal Developer Platform (IDP) across Azure tenants and
subscriptions.

The high-level roadmap lives in [`plan/plan.md`](plan/plan.md). Stage-by-stage
implementation details live in [`plan/stages/`](plan/stages/), with Stage 00
establishing the repository foundation, conventions, and quality gates.

## Current stage

Stage 06 - CI/CD and software supply chain.

This stage introduces OIDC-backed reusable GitHub Actions workflows for
Terraform, policy checks, container build/sign/SBOM, Helm publishing,
TechDocs publishing, GitOps PR creation, quay imports, and digest-pinned image
promotion.

## Local setup

1. Create or switch to a task-specific feature branch.
2. Install the pinned toolchain with `mise install` or open the repository in
   the devcontainer.
3. Run `make bootstrap`.
4. Validate changes with:

   ```sh
   make lint validate policy-test-rego policy-test-kyverno
   ```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for contribution and review guidance.
