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
tfvars JSON. The public demo route is reachable from the internet and relies on
Microsoft Entra ID sign-in plus Backstage RBAC for access control. Keep the
private ingress as the default path for non-demo profiles that require network
source restrictions. Remove any older `backstage_public_ingress_allowed_cidr`
entry from protected platform tfvars before applying this model; the public demo
route no longer uses client source IP allowlisting.

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
`backstage_public_ingress_fqdn` after apply. It also outputs
`backstage_microsoft_auth_redirect_uri`; add that URI to the Backstage Microsoft
Entra app registration's web redirect URIs before testing sign-in. When no
custom domain is available, the platform uses the Azure public IP DNS label FQDN
`<label>.<region>.cloudapp.azure.com` with an HTTP-01 Let's Encrypt issuer. The
public LoadBalancer accepts ports 80 and 443 so ACME can validate the FQDN and
browser users can reach the Entra-backed Backstage sign-in page. The platform
stack manages matching
ports 80 and 443 allow rules on the AKS user-pool subnet NSG; if these rules are
missing, the Azure Load Balancer can exist but public TCP connections will time
out.

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

When `appConfig.baseUrl`, RBAC group references, or other ConfigMap-backed
Backstage values change, the Helm chart rolls the Backstage Deployment through
checksum annotations so the running process picks up the new configuration.

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

### Backstage GitHub App

The `backstage-github-app-*` secrets are the credentials of a dedicated GitHub
App used by the Backstage catalog (template/location reads, org discovery) and
scaffolder. It is a separate registration from the Terraform-managed
`platform-vending-bot` (`infrastructure/terraform/github-app/`); Terraform only
creates the Key Vault role assignments for these secrets, never their values.

GitHub App registrations cannot be created purely through the API, so creation
is a one-time, manifest-flow step:

1. Create the app (one browser approval):

   ```bash
   HOMEPAGE_URL=https://<env>.backstage.<domain> \
   APP_NAME=pe-backstage-<env> \
   node scripts/backstage/create-backstage-github-app.mjs
   # open the printed localhost URL, click "Create GitHub App"
   ```

   The script requests the permissions Backstage needs — repository
   Administration, Contents, Pull requests, Issues, Webhooks, Workflows and
   Pages (read & write) plus Metadata (read) — and writes the new credentials to
   a local `backstage-github-app-creds.json` (git-ignored; delete after use).

2. Install the app on the platform repositories (`platform-engineering-landing-zone`
   and `platform-cluster-state`) via the install URL the script prints.

3. Seed the five Key Vault secrets from a VNet-connected runner/operator session
   (preferred, keeps the vault private) from the credentials file:

   | Key Vault secret | Manifest field |
   | --- | --- |
   | `backstage-github-app-id` | `id` |
   | `backstage-github-app-client-id` | `client_id` |
   | `backstage-github-app-client-secret` | `client_secret` |
   | `backstage-github-app-webhook-secret` | `webhook_secret` |
   | `backstage-github-app-private-key` | `pem` |

   If no VNet session is available, break-glass from an operator IP: add a scoped
   `az keyvault network-rule add --ip-address <ip>`, set
   `--public-network-access Enabled` (keep `default-action Deny`), set the
   secrets, then immediately revert both. Never disable the default-deny rule.

4. Force an External Secrets re-sync and restart Backstage so the pod reloads the
   env from the updated secret:

   ```bash
   kubectl -n backstage annotate externalsecret backstage-runtime \
     force-sync=$(date +%s) --overwrite
   kubectl -n backstage rollout restart deploy/backstage
   ```

5. Verify the catalog ingested the templates (expect the five software
   templates):

   ```bash
   SA=$(kubectl -n backstage get deploy backstage -o jsonpath='{.spec.template.spec.serviceAccountName}')
   T=$(kubectl -n backstage create token "$SA" --audience backstage --duration 10m)
   kubectl -n backstage exec deploy/backstage -- node -e \
     "fetch('http://localhost:7007/api/catalog/entities/by-query?filter=kind=template',{headers:{Authorization:'Bearer $T'}}).then(r=>r.json()).then(j=>console.log('templates='+j.totalItems))"
   ```

6. To rotate credentials, generate a new private key (or client secret) in the
   GitHub App settings, update the matching Key Vault secret(s) exactly as in
   step 3, then repeat the External Secrets resync and restart from step 4.
   Delete the superseded private key in GitHub once the new pod is healthy.


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

## Catalog templates not visible ("Integration not found")

If the Create page shows no software templates and the backend logs repeat
`Unable to read url, Integration not found` for the `templates/*/template.yaml`
locations, the Backstage GitHub App credentials are missing or wrong — most often
`backstage-github-app-id` left at a placeholder. `Integration not found` is
GitHub's own 401 for an App JWT whose issuer (App ID) does not match the signing
private key, so the catalog cannot read the private-repo template URLs.

1. Confirm the running App ID is the real numeric ID, not a placeholder:

   ```bash
   kubectl -n backstage exec deploy/backstage -- printenv GITHUB_APP_ID
   ```

2. If it is a placeholder (e.g. `1`) or the client ID is `Iv1.placeholderclientid`,
   (re)provision the app and seed the five secrets per **Backstage GitHub App**
   above, then force an External Secrets re-sync and restart Backstage.
3. Confirm the app is installed on `platform-engineering-landing-zone` with
   Contents (read) so it can read the template files.
4. Re-check with the catalog `kind=template` verification query above.

## TechDocs publish failures

1. Check the caller repository's `techdocs-publish.yml` job logs.
2. Confirm the GitHub Actions principal is present in
   `techdocs_publisher_principal_ids`.
3. Confirm the storage account private endpoint is approved and DNS resolves from
   the VNet-integrated runner.
4. Run `az storage blob list --auth-mode login` against the `techdocs` container
   from the runner to verify RBAC.
5. Re-run the publishing workflow after RBAC or DNS propagation completes.

### Platform System TechDocs

The platform's own documentation (this `docs/` tree, built from the root
`mkdocs.yml`) is published for the `platform-engineering-landing-zone` System
entity by the **Publish platform TechDocs** workflow
(`.github/workflows/techdocs-publish-platform.yml`), which runs on pushes to
`main` that touch `mkdocs.yml`/`docs/**` and on manual dispatch (choose the
target Environment). It uploads to `techdocs/default/system/platform-engineering-landing-zone`.

The Docs page stays empty until **both** are true, so check both when it does
not appear:

1. The `backstage.io/techdocs-ref` annotation on the System entity is live in
   the running catalog. It ships in `backstage/app/catalog-info.yaml`, which is
   baked into the Backstage image, so a new annotation requires a Backstage
   image rebuild and deploy (see **Upgrade**).
2. The publish workflow has run for the target Environment so the generated site
   exists in the TechDocs container at the path above.

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
4. The Backstage workload identity service principal, not the Microsoft auth app
   registration, needs read-only Microsoft Graph application permissions so the
   `microsoftGraphOrg` provider can ingest users and groups. Grant admin consent
   for `User.Read.All`, `Group.Read.All`, and `GroupMember.Read.All` to the
   service principal whose client ID is exported after the platform stack is
   applied as
   `platform_workload_identity_client_ids.backstage` and whose object ID is exported as
   `platform_workload_identity_principal_ids.backstage`:

   ```bash
   set -euo pipefail

   BACKSTAGE_CLIENT_ID="<platform_workload_identity_client_ids.backstage>"
   BACKSTAGE_SP_ID="$(az ad sp show --id "$BACKSTAGE_CLIENT_ID" --query id -o tsv)"
   GRAPH_SP_ID="$(az ad sp show --id 00000003-0000-0000-c000-000000000000 --query id -o tsv)"

   if [ -z "$BACKSTAGE_SP_ID" ] || [ -z "$GRAPH_SP_ID" ]; then
     echo "Backstage or Microsoft Graph service principal was not found." >&2
     exit 1
   fi

   # Microsoft Graph application roles:
   # User.Read.All=df021288-bdef-4463-88db-98f22de89214
   # Group.Read.All=5b567255-7703-4780-807c-7be8301ae99b
   # GroupMember.Read.All=98830695-27a2-44f7-8c18-0c3ebc9698f6
   for role_id in \
     df021288-bdef-4463-88db-98f22de89214 \
     5b567255-7703-4780-807c-7be8301ae99b \
     98830695-27a2-44f7-8c18-0c3ebc9698f6; do
     existing_assignment="$(az rest --method GET \
       --url "https://graph.microsoft.com/v1.0/servicePrincipals/${BACKSTAGE_SP_ID}/appRoleAssignments" \
       | jq -r --arg role_id "$role_id" '.value[]? | select(.appRoleId == $role_id) | .id' \
       | head -1)"
     if [ -z "$existing_assignment" ]; then
       az rest --method POST \
         --url "https://graph.microsoft.com/v1.0/servicePrincipals/${BACKSTAGE_SP_ID}/appRoleAssignments" \
         --headers 'Content-Type=application/json' \
         --body "$(jq -n --arg principalId "$BACKSTAGE_SP_ID" --arg resourceId "$GRAPH_SP_ID" --arg appRoleId "$role_id" '{principalId:$principalId,resourceId:$resourceId,appRoleId:$appRoleId}')"
     fi
   done
   ```

   Backstage scopes ingestion to the immutable Entra group object IDs in
   `backstage_microsoft_graph_group_object_ids` and their members; do not
   authorize RBAC from mutable display-name prefixes. When a guest user cannot
   sign in and Backstage reports that it cannot resolve user identity, confirm
   the guest user is a member of one of those synced groups and that a matching
   `User` entity exists in the catalog.

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
