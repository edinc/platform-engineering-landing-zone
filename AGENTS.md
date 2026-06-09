# Agent Development Guidelines

## Scope and precedence

These instructions apply to AI agents working in this repository. Follow `.github/copilot-instructions.md` for project context, architecture principles, security defaults, and repository conventions. Use this file for agent execution discipline, implementation quality, testing, and review requirements.

If instructions conflict, prefer the stricter rule that best prevents regressions, security issues, or architectural drift.

## Development workflow

- Start by understanding the relevant stage in `plan/stages/` and the source-of-truth roadmap in `plan/plan.md`.
- Keep changes small, focused, and aligned to the current stage boundaries.
- Reuse existing patterns before adding new abstractions, workflows, modules, or conventions.
- Preserve public contracts, Terraform outputs, policy behavior, workflow interfaces, and documented acceptance criteria unless the requested change explicitly updates them.
- Avoid broad fallbacks, silent failures, or catch-all error handling. Surface errors through existing repository patterns.
- Treat regression prevention as a primary requirement, not an optional cleanup step.

## Test and validation requirements

- Every implementation change must be covered by tests at the appropriate layer. Validation checks are required in addition to tests where applicable; they are not a substitute for tests.
- New behavior requires new or updated tests that prove the intended behavior.
- Bug fixes require a regression test that would fail without the fix.
- Infrastructure changes require the relevant Terraform formatting, validation, linting, policy, and plan checks already defined by the repository.
- Policy changes require engine-specific tests:
  - Azure control-plane policy: validate initiative/assignment structure and expected effects.
  - OPA/Rego policy: test with `conftest`.
  - Kyverno policy: test with `kyverno test`.
- Kubernetes, Helm, and Flux changes require manifest rendering and validation using existing repository commands such as `helm lint`, `kubeconform`, or Flux/Kustomize validation when available.
- Backstage or Node.js changes require the existing Node.js 20 and pnpm test, lint, type-check, and build commands when present.
- Documentation-only changes do not require automated tests, but agents must check stage alignment, links, numbering, terminology, and consistency with `plan/plan.md`.
- If no relevant test harness exists yet for implementation work, add the smallest appropriate test harness before completion. Do not hand off implementation work without tests. For documentation-only or planning-only work where automated tests are not applicable, document the validation performed.

## Required independent review passes

Before final handoff for any change set, run three independent review agents:

1. A correctness and regression review focused on behavior, edge cases, tests, and backwards compatibility.
2. A security and compliance review focused on secrets, identity, policy, supply chain, least privilege, and Azure security defaults.
3. An architecture and maintainability review focused on stage alignment, ownership boundaries, operational impact, and long-term simplicity.

Review passes must be independent:

- Give each reviewer the same user request, relevant repository context, and current diff.
- Do not seed reviewers with the implementer's conclusions, justification, or self-assessment.
- Do not seed one reviewer with another reviewer's findings.
- Reconcile findings after all reviews complete.
- Fix high-confidence issues before handoff.
- If material changes are made in response to review findings, rerun all three independent review agents on the updated diff before handoff.
- If a finding is intentionally not applied, record the rationale in the final response or PR notes.

## Regression avoidance checklist

- Confirm the change addresses the root cause or requested outcome, not only a narrow symptom.
- Add or update tests for changed behavior before considering the implementation complete.
- Run the smallest reliable validation set that covers the changed surfaces.
- Check adjacent docs, ADRs, runbooks, workflows, and stage files for consistency.
- Keep generated files, secrets, tenant-specific values, kubeconfigs, and private keys out of the repository.
- Prefer explicit failure over success-shaped defaults when required inputs, configuration, or dependencies are missing.

## Handoff expectations

- Summarize the meaningful change and any validation performed.
- Call out review findings that changed the implementation or any accepted residual risk.
- Do not claim completion if tests, validation, or required reviews could not be run.
