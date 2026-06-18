# Runbook: Flux reconciliation latency

## Trigger

`FluxReconciliationP95Slow` fires when the p95 reconciliation latency exceeds
five minutes for 15 minutes.

## Triage

1. Check `flux get kustomizations --all-namespaces` for suspended or failing
   reconciliations.
2. Inspect source-controller and kustomize-controller logs in `flux-system`.
3. Check GitHub availability and cluster egress to the cluster-state repository.
4. Confirm no large tenant PR changed an excessive number of manifests.

## Mitigation

1. Revert or fix the failing cluster-state change through a PR.
2. Resume suspended Flux resources only after identifying the owner.
3. If egress is blocked, use the egress exception workflow rather than
   opening broad outbound access.
4. If controller resources are saturated, adjust controller Helm values through
   `platform-gitops`.

## Recovery

1. Confirm `gotk_reconcile_duration_seconds` p95 is below five minutes.
2. Confirm all platform Kustomizations are ready.
3. Record any follow-up in the monthly platform SLO review.
