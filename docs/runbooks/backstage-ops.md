# Backstage operations

Stage 09 runs Backstage in AKS through Flux and the Stage 06 supply chain.

## Upgrade

1. Let Renovate open dependency updates for `backstage/app`, the Backstage Helm
   chart, and community plugin packages.
2. Confirm `ci-backstage.yml` passes app tests, chart lint, and Stage 09
   contracts.
3. Publish the signed image and Helm chart from `main`.
4. Promote by updating `backstage_image_digest`, `backstage_chart_digest`, and
   `backstage_chart_version` in the platform Terraform inputs for the target
   environment.
5. Confirm the dedicated `backstage-<env>` Flux configuration reconciles and that
   the Backstage availability panel in `grafana-dashboard-platform-slos` stays
   green.

## Postgres restore

1. Follow `docs/runbooks/dr-matrix.md` for the environment RTO/RPO target.
2. Prefer PostgreSQL Flexible Server PITR or geo-restore for `prod`.
3. Restore into an isolated server first and validate the `backstage` database.
4. Update `backstage_postgres_host` only after the restored database is verified.
5. Roll Backstage pods one at a time and check `/healthz`, catalog reads, and
   TechDocs reads.

PostgreSQL Entra authentication through Workload Identity is preferred. The
current Terraform-managed PostgreSQL server remains password-auth by default
until Entra admin/user mapping is configured, so `backstage_postgres_auth_mode`
defaults to `password` and uses the Terraform Postgres administrator login unless
`backstage_postgres_user` is set to a separately provisioned database role. Switch
it to `entra` only after the mapped Backstage principal can connect with an Entra
token.

## TechDocs publish failures

1. Check the caller repository's `techdocs-publish.yml` job logs.
2. Confirm the GitHub Actions principal is present in
   `techdocs_publisher_principal_ids`.
3. Confirm the storage account private endpoint is approved and DNS resolves from
   the VNet-integrated runner.
4. Run `az storage blob list --auth-mode login` against the `techdocs` container
   from the runner to verify RBAC.
5. Re-run the publishing workflow after RBAC or DNS propagation completes.

## Kubernetes plugin troubleshooting

1. Never add or upload kubeconfigs to Backstage.
2. Confirm the `backstage` ServiceAccount has the expected
   `azure.workload.identity/client-id` annotation.
3. Confirm the managed identity has AKS Cluster User and the in-cluster read-only
   RBAC required by Stage 09. Direct Kubernetes plugin permissions are
   operator-only until Stage 10 creates namespace-scoped team RoleBindings.
4. Check Backstage backend logs for AAD token or Kubernetes authorization
   failures.
5. Validate component annotations include `backstage.io/kubernetes-id`.

## RBAC and audit

1. Group mappings live in `backstage-rbac-groups`; do not hard-code Entra group
   names in policy code.
2. Confirm non-admin delete attempts return denied decisions and appear in
   Backstage audit logs.
3. For onboarding, add users to Entra groups that sync through Microsoft Graph;
   do not change code for each team.
4. The Microsoft Graph application used by Backstage needs read-only Graph
   permissions for users and groups. Stage 09 scopes ingestion to the immutable
   Entra group object IDs in `backstage_microsoft_graph_group_object_ids` and
   their members; do not authorize RBAC from mutable display-name prefixes.

## Catalog reconciliation

The `backstage-catalog-reconciler` CronJob runs every 15 minutes and writes a
structured `platform-drift` log when GitHub catalog files or vended namespaces
are missing from the Backstage catalog. It also posts to the optional
`backstage-catalog-reconciler-teams-webhook-url` secret for the platform drift
channel. Treat sustained drift as a platform incident for the owning team.
