# DR matrix

Capability: reliability operations

The platform designs the DR posture up front. Restore drills validate these objectives
with restore drills and incident workflow exercises.

| Tier | Component | RTO | RPO | Mechanism | Validation |
|------|-----------|-----|-----|--------------------|---------------------|
| Critical | Postgres (Backstage + platform) | 1h | 5min | PITR 35d; geo-redundant backup for prod; CMK follow-up | PITR restore drill |
| Critical | ACR | 1h | 0 | Premium geo-replication to paired region | Registry failover/import drill |
| Critical | Key Vault | 1h | 24h | Soft-delete 90d, purge protection, private access | Vault recovery drill |
| Important | AKS cluster | 4h | 24h | Terraform redeploy; AKS Backup follow-up for K8s resources/PVs | Cluster + backup restore drill |
| Important | Terraform state | 1h | 1h | RA-GRS + versioning | State restore exercise |
| Standard | Workload PVCs | 8h | 24h | AKS Backup follow-up per storage driver support | Per-driver restore drill |

## Operating notes

1. Do not treat geo-redundant backup as tested until a restore drill completes.
2. Key Vault RPO must stay at or below the RPO of any service encrypted with its
   keys; CMK rollout requires paired-vault backup documentation.
3. ACR geo-replication uses one login server; failover is DNS-routed by Azure.
4. AKS control plane is recreated from Terraform in DR. Cluster state comes from
   the Flux-watched `platform-cluster-state` repository.
