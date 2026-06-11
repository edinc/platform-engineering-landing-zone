# Runbook: GitHub Advanced Security cost and opt-in (Stage 06)

This runbook records when to enable GHAS-backed CodeQL and how to control its
licence footprint.

Related decision: [ADR-0019](../adr/0019-ci-scanning.md).

## Default posture

CodeQL support is built into `.github/workflows/policy-checks.yml`, but
`run_codeql` defaults to `false`. Enable it only for repositories where GHAS is
licensed and the owning team accepts the seat or committer cost.

## Opt-in matrix

| Repository type | CodeQL default | Reason |
| --- | --- | --- |
| Platform repository | Opt in when GHAS is available | Highest supply-chain impact; should be first to enable. |
| `platform-cluster-state` | Usually off | Mostly declarative YAML; Kyverno/kubeconform are stronger signals. |
| Golden-path app repositories | Team opt in | Cost belongs to the consuming product/team. |
| Public sample repositories | Case by case | Public CodeQL may be free, but support burden remains. |

## Enable CodeQL for a caller

In a caller workflow, invoke the reusable policy workflow with CodeQL enabled:

```yaml
jobs:
  policy:
    uses: ./.github/workflows/policy-checks.yml
    with:
      run_codeql: true
      codeql_languages: javascript-typescript,python
```

Confirm repository settings allow code scanning alerts and that branch protection
does not require a CodeQL status check until the first run succeeds.

## Cost review

Review GHAS usage monthly with the repository owner:

1. Count enabled repositories and active committers.
2. Confirm generated golden-path repositories have an owner-approved opt-in.
3. Disable CodeQL for archived or demo-only repositories.
4. Keep Trivy, Checkov, conftest, and Kyverno checks enabled even when CodeQL is
   disabled.

Dependabot security alerts are managed through repository security settings, not
through `.github/dependabot.yml`. Renovate vulnerability-alert PRs stay disabled
to avoid duplicate CVE PRs.

## Disable CodeQL

Set `run_codeql: false` or remove the input override from the caller workflow.
Leave historical alerts visible for audit unless the repository is archived or
deleted.
