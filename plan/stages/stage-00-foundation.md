# Stage 00 — Foundation & repo bootstrap

## Goal

Establish the repository, conventions, and CI test harness so that every
subsequent stage merges through a consistent quality gate.

## Scope (in)

- Repository layout (matches `plan.md` §8).
- Coding/structural conventions (Terraform, Helm, Kubernetes manifests, Python
  scripts).
- **ADR template** in `docs/adr/0000-template.md`; numbering convention.
- **CONTRIBUTING.md**, **CODEOWNERS**, branch protection, PR template.
- **Pre-commit hooks** (`pre-commit` framework).
- **CI test harness** (GitHub Actions) running on every PR:
  - `terraform fmt -check` + `terraform validate`
  - `tflint` with Azure ruleset
  - `tfsec` *or* `checkov` (pick one; default `checkov`)
  - `conftest` against **OPA Rego** policies (e.g., Terraform plan-time
    assertions in `policies/rego/`).
  - `kyverno test` against Kyverno YAML policies in `policies/kyverno/`
    (`conftest` does **not** validate Kyverno semantics — different engines).
  - `kubeconform` against Kubernetes manifests
  - `cspell` / `markdownlint` for docs (optional)
  - `helm lint` for charts
  - `ci-backstage.yml` (Node.js 20, pnpm) for `backstage/` workspace —
    stub at Stage 00, fleshed out in Stage 09.
- Make targets / Taskfile entries that wrap the above for local use.
- `tools.version` (asdf/mise) pinning: `terraform`, `kubectl`, `helm`, `kustomize`,
  `flux`, `cosign`, `azure-cli`, `gh`, `node`, `python`.
- Devcontainer (`.devcontainer/`) so contributors get a reproducible toolchain.

## Scope (out)

- Any Azure deployment (Stage 01 onwards).
- Backstage code (Stage 09).

## Deliverables

- Folder skeleton committed (see `plan.md` §8).
- `.github/workflows/ci.yml` running the test harness.
- `.github/workflows/ci-backstage.yml` stub (Node.js 20 + pnpm matrix; full
  build added in Stage 09).
- **GitHub Environments** provisioned: `dev`, `nonprod`, `prod`, plus
  `bootstrap` (Stage 01) — with deployment protection rules + required
  reviewers documented in `docs/adr/0023-scm-branching.md`. Their existence
  is a prerequisite for OIDC federation (Stage 01) and image-promotion
  protection (Stage 06).
- `docs/adr/0000-template.md`.
- `docs/adr/README.md` — canonical ADR index (extends `plan.md` §9 with
  ADRs 0021–0046; updated as stages introduce them).
- `docs/runbooks/README.md` placeholder.
- `.pre-commit-config.yaml`.
- `.tool-versions` (asdf/mise).
- `.devcontainer/devcontainer.json`.
- `CONTRIBUTING.md`, `CODEOWNERS`, `.github/PULL_REQUEST_TEMPLATE.md`.
- `Makefile` (or `Taskfile.yml`) with at least: `bootstrap`, `lint`, `validate`,
  `policy-test-rego`, `policy-test-kyverno`, `plan`, `apply`, `docs`.

## Dependencies

- None (this is Stage 0).

## Decisions / ADRs to capture in this stage

- **ADR-0001** Primary IaC = Terraform.
- **ADR-0021** Pre-commit framework + which linters run locally vs CI.
- **ADR-0023** SCM choice (GitHub Cloud or GHEC) and branching model
  (trunk-based with short-lived branches) + GitHub Environments scheme.
- **ADR-0047** Policy testing split — OPA Rego via `conftest` vs Kyverno
  via `kyverno test`; what each gates.

> **ADR-0022** (Conventional Commits + Release Please) moved to Stage 06,
> where reusable workflow / Helm chart releases require it.

## Technologies

| Concern | Choice |
|---------|--------|
| SCM | GitHub |
| CI | GitHub Actions |
| IaC lint | `tflint` (Azure ruleset) |
| IaC security | `checkov` (default) |
| OPA policy testing | `conftest` against `policies/rego/` |
| Kyverno policy testing | `kyverno test` against `policies/kyverno/tests/` |
| Manifest validation | `kubeconform` |
| Tool pinning | `mise` (or `asdf`) via `.tool-versions` |
| Local pre-commit | `pre-commit` |
| Devcontainer | VS Code devcontainer JSON + Dockerfile |

## Acceptance criteria

1. A new contributor can clone the repo, open it in a devcontainer (or run
   `mise install`), and `make lint validate policy-test-rego policy-test-kyverno`
   passes locally.
2. PRs that violate Terraform formatting, lint, security, or manifest validation
   are blocked by required status checks.
3. ADR template exists, `docs/adr/0001-iac.md` documents the Terraform
   decision, and `docs/adr/README.md` indexes ADRs 0001+ with a "next-free
   number" pointer.
4. CODEOWNERS routes infrastructure, Backstage, policies, and docs to distinct
   reviewer groups (placeholders OK at this stage).
5. GitHub Environments `dev`/`nonprod`/`prod`/`bootstrap` exist and are
   referenced by at least one workflow file (no-op deploy stub in
   `ci-backstage.yml`).

## Risks

- **CI feedback time creeps up** as the harness grows → cache `~/.terraform.d`,
  `~/.cache/pre-commit`, container layers.
- **Tool drift** across contributors → enforce `mise`/`asdf` via CI sanity check.
