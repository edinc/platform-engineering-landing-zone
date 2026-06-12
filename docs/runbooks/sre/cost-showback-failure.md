# Runbook: cost showback failure

## Trigger

`CostShowbackExportStale` fires when the cost allocator has not published a
showback CSV within the expected daily window.

## Triage

1. Check the Cost Management export status with `az costmanagement export show`.
2. Confirm new CSV blobs exist in the ALZ-owned export container.
3. Check the cost allocator Function App health and latest invocation logs.
4. Verify the Function managed identity still has Storage Blob Data Reader on
   the export container and Storage Blob Data Contributor on the showback
   container.

## Mitigation

1. Re-run the Function after the source export is available.
2. Restore missing RBAC assignments through Terraform; do not grant account keys.
3. If the export path changed, update Terraform variables and run a plan before
   applying.
4. Charge unallocated or malformed-tag rows to `platform-overhead` until source
   tagging is corrected.

## Recovery

1. Confirm a new `showback/YYYY/MM/DD/team-showback.csv` exists.
2. Confirm rows aggregate by `costCenter`, `team`, and `product`.
3. Link any persistent tagging gaps to the owning team.
