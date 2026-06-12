# Runbook: platform SLO burn

## Trigger

An SLO burn-rate alert indicates one of the platform error budgets is being
consumed faster than its configured target allows.

## Triage

1. Open the Platform SLOs Grafana dashboard and identify the burning SLO.
2. Check whether the burn is caused by a known deployment, Azure service health
   event, policy failure, or cluster capacity issue.
3. Confirm whether customer-facing golden paths or Backstage are affected.
4. For SEV1/SEV2 alerts, start the incident workflow and assign an incident
   commander.

## Mitigation

1. Pause risky rollouts through Flux or GitHub Actions if the burn started after
   a deployment.
2. Scale or disable the failing component only through its source of truth:
   Terraform for Azure infrastructure, Flux for Kubernetes state.
3. If Kyverno admission latency is the cause, inspect recent policy changes and
   webhook health before disabling enforcement.
4. Update the status page when users experience degraded platform paths.

## Recovery

1. Confirm burn-rate alerts resolve for at least one short window.
2. Link the incident record or improvement issue to the SLO review.
3. Add or adjust tests for the failure mode before closing follow-up work.
