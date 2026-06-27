# Contributing

This repository implements the Azure Platform Engineering Landing Zone. It is an
opinionated Internal Developer Platform for Azure; before changing it, skim the
[architecture reference](docs/architecture/README.md) and the
[how-it-works guides](docs/how-it-works/README.md) for the capability you are
touching.

## Vocabulary

Describe changes by **capability**, not by internal phase numbers. Use the
capability names from the [architecture reference](docs/architecture/README.md)
and [how-it-works guides](docs/how-it-works/README.md) — for example
"Azure foundation", "connectivity & egress", "platform shared services",
"supply chain & CI/CD", "GitOps platform", "developer portal", and "golden
paths". Public-facing docs and reader-facing comments must not reintroduce
internal phase/stage numbering.

## Workflow

1. Create or switch to a task-specific feature branch before implementation. Do
   not implement directly on `main` unless explicitly instructed.
2. Read the relevant how-it-works guide and any ADRs that govern the changed
   area.
3. Keep changes focused and aligned to one capability boundary.
4. Add or update tests for behavior, policy, workflow, or infrastructure
   changes. New behavior needs a test that proves it; bug fixes need a
   regression test that would fail without the fix.
5. Run the smallest reliable validation set before opening a PR.

## Local toolchain

Use the devcontainer or install the pinned toolchain (see
[`.tool-versions`](.tool-versions)):

```sh
mise install
make bootstrap
```

`make bootstrap` requires `mise`; the devcontainer installs it before running
the bootstrap target.

## Validation

Run the checks relevant to what you changed. The full local gate is:

```sh
make lint validate policy-test-rego policy-test-kyverno
```

| Change type | Run |
| --- | --- |
| Terraform / infrastructure | `make terraform-fmt terraform-validate tflint checkov` (or `make lint validate`) |
| OPA/Rego plan-time policy | `make policy-test-rego` (conftest) |
| Kyverno admission policy | `make policy-test-kyverno` (`kyverno test`) |
| Azure Policy / firewall allowlist | `make policy-test-azure` |
| Kubernetes / Flux / Helm | `make kubeconform helm-lint` |
| Request contracts (vending/onboarding) | `make contract-test` |
| Backstage / Node.js | the app's `yarn tsc`, lint, and test scripts under `backstage/` |
| Documentation | `mkdocs build --strict` (no broken links/anchors) |

Documentation-only changes do not require automated tests, but check links,
anchors, and consistency with the architecture reference and how-it-works guides.

## Required review passes

Implementation changes require three **independent** review passes before final
handoff (see [`AGENTS.md`](AGENTS.md) for the full discipline):

1. **Correctness & regression** — behavior, edge cases, tests, backwards
   compatibility.
2. **Security & compliance** — secrets, identity, policy, supply chain, least
   privilege, and Azure security defaults.
3. **Architecture & maintainability** — ownership boundaries, operational impact,
   and long-term simplicity.

Do not seed a reviewer with the implementer's conclusions or another reviewer's
findings. Reconcile after all reviews, fix high-confidence issues, and rerun the
reviews if material changes result.

## Pull requests

Every PR should state the capability being changed, the acceptance criteria it
addresses, and the validation that was run. Fill in the pull request template.

Repository administrators should apply the branch protection ruleset in
[`.github/rulesets/main-branch-protection.json`](.github/rulesets/main-branch-protection.json)
so required status checks block merges into `main`.

The current CODEOWNERS file uses `@edinc` as an enforceable fallback because the
repository is user-owned. Replace those entries with the documented organization
teams if the repository moves under a GitHub organization. Do not enable required
code-owner review until the repository has at least one independent reviewer or
valid organization teams, otherwise pull requests can become unmergeable.

## Licensing

This project is licensed under the [MIT License](LICENSE). By contributing, you
agree that your contributions are licensed under the same terms. Do not add code
or content under an incompatible license, and preserve existing copyright and
license notices.

## Never commit secrets

Do not commit secrets, kubeconfigs, tenant-specific credentials, subscription or
tenant IDs, private keys, or generated Terraform state. Local files such as
`backend.hcl`, `terraform.tfvars`, and `*.auto.tfvars` are gitignored — keep them
that way.
