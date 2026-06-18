# Runbooks

Operational runbooks for the platform landing zone. Stage 12 expands this
catalog with incident response, restore drills, and DR procedures.

| Runbook | Purpose | Stage |
| --- | --- | --- |
| [`bootstrap.md`](bootstrap.md) | Bootstrap and secret zero onto an empty/brownfield subscription | 01 |
| [`subscription-onboarding.md`](subscription-onboarding.md) | Existing-subscription onboarding/readiness against an external ALZ | 02 |
| [`policy-exception.md`](policy-exception.md) | Time-bound policy exemption workflow (request -> approve -> apply -> audit) | 02 |
| [`egress-exception.md`](egress-exception.md) | Time-bound outbound egress exception workflow for firewall and NetworkPolicy changes | 03 |
| [`dr-matrix.md`](dr-matrix.md) | RTO/RPO matrix and DR validation handoff | 04 |
| [`aks-baseline.md`](aks-baseline.md) | AKS baseline operations, upgrades, and follow-ups | 04 |
| [`region-matrix.md`](region-matrix.md) | Regional feature support matrix for Stage 04 services | 04 |
| [`vending.md`](vending.md) | Subscription and AKS namespace vending operations | 05 |
| [`release.md`](release.md) | Signed image, Helm artifact, and PR-based promotion operations | 06 |
| [`renovate.md`](renovate.md) | Renovate dependency update operations | 06 |
| [`ghas-cost.md`](ghas-cost.md) | GHAS and CodeQL opt-in and cost controls | 06 |
| [`secret-rotation.md`](secret-rotation.md) | Key Vault-backed secret and certificate rotation contract | 07 |
| [`cert-management.md`](cert-management.md) | cert-manager issuer choice and troubleshooting | 07 |
| [`platform-slos.md`](platform-slos.md) | Platform SLO targets, monthly review cadence, and alert requirements | 08 |
| [`backstage-ops.md`](backstage-ops.md) | Backstage upgrade, restore, TechDocs, Kubernetes plugin, RBAC, and catalog reconciliation operations | 09 |
| [`ownership-matrix.md`](ownership-matrix.md) | Canonical RACI for platform, workload, identity, GitOps, and cost artifacts | 10 |
| [`team-onboarding.md`](team-onboarding.md) | Team onboarding request, idempotency, and partial-failure recovery | 10 |
| [`team-decommissioning.md`](team-decommissioning.md) | Team sunset, ownership reassignment, namespace retirement, and access removal | 10 |
| [`golden-paths.md`](golden-paths.md) | Stage 11 template operation, generated repo handoff, and failure handling | 11 |
