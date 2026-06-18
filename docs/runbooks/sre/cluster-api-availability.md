# Runbook: cluster API availability

## Trigger

`ClusterApiAvailabilityBurn` fires when AKS API server 5xx responses consume the
availability error budget too quickly.

## Triage

1. Check Azure Resource Health and Azure Service Health for the AKS region.
2. Run `az aks show` for the cluster provisioning state and power state.
3. Review API server metrics in Azure Monitor and Managed Prometheus.
4. Confirm whether node pressure, DNS, or private endpoint routing is affecting
   operator access.

## Mitigation

1. Avoid Terraform or Flux changes until the API server is stable unless the
   change is the known fix.
2. Escalate to Microsoft support for regional/API-server faults.
3. If private connectivity is the issue, use the connectivity runbooks
   and keep default-deny egress intact.
4. Communicate platform impact through the status page for user-visible outages.

## Recovery

1. Confirm `az aks show` succeeds and the API error ratio returns under target.
2. Confirm Flux catches up without manual kubectl drift.
3. Record timeline and any support case in the incident notes.
