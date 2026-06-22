# Runbooks

Operational runbooks for the platform landing zone. The catalog covers
bootstrap, subscription onboarding, connectivity, platform services,
Backstage, onboarding, golden paths, and day-2 operations.

| Runbook | Purpose |
| --- | --- |
| [`bootstrap.md`](bootstrap.md) | Bootstrap and secret zero onto an empty/brownfield subscription. |
| [`subscription-onboarding.md`](subscription-onboarding.md) | Existing-subscription onboarding/readiness against an external ALZ. |
| [`policy-exception.md`](policy-exception.md) | Time-bound policy exemption workflow (request -> approve -> apply -> audit). |
| [`egress-exception.md`](egress-exception.md) | Time-bound outbound egress exception workflow for firewall and NetworkPolicy changes. |
| [`dr-matrix.md`](dr-matrix.md) | RTO/RPO matrix and DR validation handoff. |
| [`aks-baseline.md`](aks-baseline.md) | AKS baseline operations, upgrades, and follow-ups. |
| [`region-matrix.md`](region-matrix.md) | Regional feature support matrix for Azure platform services. |
| [`vending.md`](vending.md) | Subscription and AKS namespace vending operations. |
| [`release.md`](release.md) | Signed image, Helm artifact, and PR-based promotion operations. |
| [`renovate.md`](renovate.md) | Renovate dependency update operations. |
| [`ghas-cost.md`](ghas-cost.md) | GHAS and CodeQL opt-in and cost controls. |
| [`secret-rotation.md`](secret-rotation.md) | Key Vault-backed secret and certificate rotation contract. |
| [`cert-management.md`](cert-management.md) | cert-manager issuer choice and troubleshooting. |
| [`flux-extension-recovery.md`](flux-extension-recovery.md) | Controlled recovery for stale AKS Flux extension settings and GitOps rehydration. |
| [`platform-slos.md`](platform-slos.md) | Platform SLO targets, monthly review cadence, and alert requirements. |
| [`backstage-ops.md`](backstage-ops.md) | Backstage upgrade, restore, TechDocs, Kubernetes plugin, RBAC, and catalog reconciliation operations. |
| [`ownership-matrix.md`](ownership-matrix.md) | Canonical RACI for platform, workload, identity, GitOps, and cost artifacts. |
| [`team-onboarding.md`](team-onboarding.md) | Team onboarding request, idempotency, and partial-failure recovery. |
| [`team-decommissioning.md`](team-decommissioning.md) | Team sunset, ownership reassignment, namespace retirement, and access removal. |
| [`golden-paths.md`](golden-paths.md) | Golden-path template operation, generated repo handoff, and failure handling. |
