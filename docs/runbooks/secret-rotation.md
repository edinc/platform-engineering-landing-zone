# Secret rotation

Capability: GitOps platform

This runbook defines the rotation contract for Key Vault-backed secrets consumed
through Secrets Store CSI or External Secrets Operator.

## Rotation contract

Every golden-path service must record these fields in its catalog metadata or
service documentation:

| Field | Requirement |
|-------|-------------|
| Owner | Team or on-call rotation that can approve and execute rotation. |
| Source | Key Vault name, secret/certificate name, and environment. |
| Maximum age | `90d` default, shorter for credentials with external compliance requirements. |
| Reload signal | `SIGHUP`, pod restart, controller reload, or CSI re-mount. |
| Validation | Command, dashboard, or synthetic check proving the new value is active. |
| Rollback | Previous Key Vault version and conditions for re-enabling it. |

## Standard procedure

1. Open a change request or PR that identifies the secret, owner, and reload
   plan.
2. Write the new value or certificate version to Key Vault. Do not commit the
   value to Git, workflow variables, or Kubernetes manifests.
3. Confirm the workload identity has only the required Key Vault data-plane role
   for the secret scope.
4. Trigger the documented reload signal:
   - CSI mount consumers: restart pods if the application does not hot-reload
     mounted files.
   - ESO consumers: wait for the ExternalSecret refresh interval, then restart
     pods if the application reads secrets only at startup.
   - cert-manager private CA: rotate Key Vault `ca.crt` and `ca.key`, then
     restart cert-manager after the synced secret updates.
5. Run the validation check and attach evidence to the change request.
6. Keep the previous Key Vault version enabled until the rollback window closes,
   then disable it.

## Emergency rotation

1. Disable the compromised Key Vault version if active exploitation is suspected.
2. Create a replacement version and force a workload rollout.
3. Notify the service owner, platform on-call, and security approver.
4. Open a post-incident PR that updates the service rotation contract if the
   reload or validation step was incomplete.
