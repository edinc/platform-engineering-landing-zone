# GitHub Copilot Instructions

## Project context

This repository builds an opinionated Azure Platform Engineering Landing Zone: a secure, compliant, reusable Internal Developer Platform for Azure tenants and subscriptions.

Use `plan/plan.md` as the high-level source of truth and `plan/stages/` as the implementation roadmap. Keep changes aligned with the stage boundaries, dependencies, deliverables, ADRs, and acceptance criteria documented there.

AI agents must also follow `AGENTS.md` for execution discipline, test coverage, independent review requirements, and regression avoidance.

## Core principles

- Prefer Azure-native services and align designs with CAF, Azure Landing Zones, and Azure Well-Architected guidance.
- Terraform is the primary IaC language. Use Azure Verified Modules where available and GA, with pinned versions. Treat Bicep as a documented future option unless a stage or ADR says otherwise.
- GitOps is the default delivery model for Kubernetes state. Flux owns in-cluster desired state.
- Keep clear ownership boundaries: an existing ALZ owns management groups and tenant/MG-scoped policy; Terraform in this repo owns subscription-scoped baseline and platform shared infrastructure; Flux owns Kubernetes resources; Azure Service Operator v2 owns workload-team Azure dependencies; Backstage initiates workflows but is not the source of truth.
- Design for three profiles: `demo`, `nonprod`, and `prod`, with cost-conscious defaults for `demo` and production-grade HA/security for `prod`.
- Be brownfield-aware. Avoid assumptions that every tenant or subscription starts empty.

## Security and compliance defaults

- Prefer OIDC federation and managed identities over static credentials.
- Never commit secrets, tenant-specific credentials, private keys, or generated kubeconfigs.
- Use Key Vault with RBAC and Private Link for secrets and certificates.
- Use secure-by-default AKS patterns: private clusters, Workload Identity, Azure CNI Overlay with Cilium, Pod Security Admission, Kyverno, signed images, and default-deny network posture.
- Kyverno is the single in-cluster admission engine. Do not enable the Azure Policy Gatekeeper add-on for AKS unless a future ADR explicitly changes that decision.
- Preserve the compliance baseline: inherited CIS/ALZ policy posture, Defender for Cloud, required tags, central logging/diagnostics integration, and policy exception workflows.

## Repository conventions

- Keep documentation, IaC, policies, workflows, and templates consistent with the planned structure in `plan/plan.md`.
- Add or update ADRs when introducing architectural decisions, tradeoffs, new platform capabilities, or deviations from the roadmap.
- Add or update runbooks when changing operational procedures, incident workflows, recovery steps, or support expectations.
- Keep stage documents in the existing format: goal, scope in/out, deliverables, dependencies, decisions/ADRs, technologies, acceptance criteria, and risks.
- Use precise, implementation-oriented Markdown. Prefer tables for structured choices and numbered acceptance criteria for verifiable outcomes.

## Infrastructure guidance

- For Terraform, prefer reusable modules under the planned `infrastructure/terraform/_modules/` layout and environment compositions under `infrastructure/terraform/envs/{demo,nonprod,prod}/`.
- Keep provider versions, module versions, and tool versions pinned.
- Validate Terraform with existing repository commands and CI patterns before considering infrastructure changes complete.
- Preserve stage ordering: bootstrap and secret zero before subscription baseline; connectivity and egress before platform shared services; vending before CI/CD; CI/CD before GitOps and Backstage.

## Policy and Kubernetes guidance

- Keep Azure Policy, OPA/Rego, and Kyverno concerns separate:
  - Azure Policy governs Azure control-plane requirements.
  - OPA/Rego via `conftest` validates Terraform plan-time assertions.
  - Kyverno validates and mutates Kubernetes resources in-cluster.
- Test Kyverno policies with `kyverno test`; do not assume `conftest` validates Kyverno semantics.
- Keep Kubernetes manifests Flux-compatible and environment-aware.

## Backstage and developer experience

- Backstage is the developer portal for golden paths, catalog, TechDocs, and platform workflows.
- When Backstage code exists, use Node.js 20 and pnpm unless repository tooling says otherwise.
- MVP Backstage work should favor configuration and community plugins over custom plugin development.
- Golden paths should include CI, SBOM, signing, GitOps, dashboards, SLOs, cost tags, TechDocs, and ownership metadata by default.

## Validation expectations

- For documentation-only changes, check links, numbering, stage alignment, and consistency with the plan.
- For code, IaC, policy, Kubernetes, or workflow changes, run the relevant existing format, lint, validate, policy-test, and build commands. Do not introduce new tooling without a documented reason.
