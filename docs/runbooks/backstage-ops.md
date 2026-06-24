# Backstage operations

Backstage runs in AKS through Flux and the reusable supply-chain workflows.

## Upgrade

1. Let Renovate open dependency updates for `backstage/app`, the Backstage Helm
   chart, and community plugin packages.
2. Confirm `ci-backstage.yml` passes app tests, chart lint, and Backstage
   contracts.
3. Run **Backstage CI** from `main` to publish the signed Backstage image,
   catalog reconciler image, and Helm chart. The workflow summary prints the
   digest values expected by the platform Terraform stack.
4. Promote by updating `backstage_image_digest`,
   `backstage_catalog_reconciler_image_digest`, `backstage_chart_digest`, and
   `backstage_chart_version` in the protected platform Terraform tfvars JSON for
   the target environment, then dispatch **Deploy Terraform stack (Stages
   02-11)** for the `platform` stack.
   The platform stack creates the default Backstage and catalog-reconciler
   managed identities plus federated credentials; set identity variables only
   when adopting brownfield identities.
5. Confirm the dedicated `backstage-<env>` Flux configuration reconciles and that
   the Backstage availability panel in `grafana-dashboard-platform-slos` stays
   green.
6. Re-run **Backstage CI** with `run_azure_smoke=true` to validate the deployed
   AKS, TechDocs storage, private endpoint, and readiness endpoint wiring.

## Public demo access

The default Backstage ingress remains private. Demo environments can enable a
separate public Backstage-only ingress by setting
`enable_backstage_public_ingress=true` in the protected platform Terraform
tfvars JSON. Set `backstage_public_ingress_allowed_cidr` to the operator source
IP CIDR, for example `203.0.113.10/32`, to restrict access.

The public path uses a dedicated `ingress-nginx-public` controller that watches
only its own namespace and the `backstage-public` IngressClass. It reaches
Backstage through an `ExternalName` backend service pointing to
`backstage.backstage.svc.cluster.local`; it does not need read access to
Backstage runtime secrets and does not expose the AKS API server or the private
platform ingress controller.
The public route resources are reconciled by a separate wait-free Flux
Kustomization so public certificate issuance cannot block the private Backstage
release.
Terraform outputs `backstage_public_ingress_ip_address` and
`backstage_public_ingress_fqdn` after apply. When no custom domain is available,
the platform uses the Azure public IP DNS label FQDN
`<label>.<region>.cloudapp.azure.com` with an HTTP-01 Let's Encrypt issuer. The
public LoadBalancer accepts ports 80 and 443 so ACME can validate the FQDN, while
the Backstage Ingress preserves client IPs and enforces
`backstage_public_ingress_allowed_cidr`.

Disabling `enable_backstage_public_ingress` reconciles the public controller to
zero replicas and removes its LoadBalancer Service. The inert
`backstage-public` Ingress object can remain in the
cluster with its ExternalName backend service. The public TLS Secret is stored in
the `ingress-nginx-public` namespace as the controller default certificate so the
public controller does not need read access to Backstage runtime secrets.
Cert-manager may retain or renew that TLS Secret while the manifest is present,
but there is no public LoadBalancer path while the controller Service is
disabled. Do not rely on Flux suspension as a disable mechanism because it does
not uninstall a previously-created LoadBalancer.

## Runtime secrets

Backstage runtime secrets live in the platform Key Vault and are consumed by
External Secrets / CSI from inside the private AKS network. Seed real values from
a VNet-connected runner or operator session before enabling `enable_backstage`:

| Secret name | Purpose |
| --- | --- |
| `backstage-session-secret` | Backstage auth session signing secret. |
| `backstage-microsoft-auth-client-secret` | Entra app client secret for Microsoft auth. |
| `backstage-github-app-id` | GitHub App numeric ID. |
| `backstage-github-app-client-id` | GitHub App OAuth client ID. |
| `backstage-github-app-client-secret` | GitHub App OAuth client secret. |
| `backstage-github-app-webhook-secret` | GitHub App webhook secret. |
| `backstage-github-app-private-key` | GitHub App private key PEM. |
| `backstage-catalog-reconciler-github-token` | Token used by the catalog drift reconciler. |
| `backstage-catalog-reconciler-teams-webhook-url` | Optional Teams webhook for drift alerts. |
| `backstage-postgres-password` | Required only when `backstage_postgres_auth_mode=password`. |

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
   RBAC required by Backstage. Direct Kubernetes plugin permissions are
   operator-only until namespace vending creates namespace-scoped team RoleBindings.
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
   permissions for users and groups. Backstage scopes ingestion to the immutable
   Entra group object IDs in `backstage_microsoft_graph_group_object_ids` and
   their members; do not authorize RBAC from mutable display-name prefixes.

## Catalog reconciliation

The `backstage-catalog-reconciler` CronJob runs every 15 minutes and writes a
structured `platform-drift` log when GitHub catalog files or vended namespaces
are missing from the Backstage catalog. It also posts to the optional
`backstage-catalog-reconciler-teams-webhook-url` secret for the platform drift
channel. Treat sustained drift as a platform incident for the owning team.

For demo environments, a `backstage-catalog-reconciler-github-token` value that
starts with `placeholder` intentionally disables GitHub repository discovery and
emits a `github-token-disabled` log event. Namespace drift checks still run.
Seed a real GitHub token to enable repository catalog drift detection.
