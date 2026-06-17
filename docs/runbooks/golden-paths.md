# Golden paths v1 runbook

Stage: 11 - golden paths v1

Use this runbook to operate and support the three MVP Backstage templates:
`aks-workload-namespace`, `aks-microservice`, and `aca-service`.

## Prerequisites

| Requirement | Purpose |
| --- | --- |
| Stage 10 team onboarding complete | Application team has Entra/GitHub groups and Backstage RBAC mapping. |
| Namespace vending variables configured | `vend-namespace.yml` can validate, plan, and apply namespace requests. |
| Stage 06 reusable workflows available | Generated repos can build, sign, publish SBOMs, publish charts, and push GitOps PRs. |
| Stage 04 platform outputs available | AKS, ACR, Key Vault, and ACA environment IDs are supplied to templates. |
| TechDocs storage configured | Generated repos can publish TechDocs through `techdocs-publish.yml`. |

## AKS workload namespace

1. Confirm the team exists in Backstage and has an immutable Entra group object
   ID.
2. Run `aks-workload-namespace` with the team, product, environment, explicit
   DNS-safe namespace, region, and quota tier.
3. Review the generated `NamespaceVendingRequest` and Resource entity.
4. Merge after platform and security approval. The protected vending workflow
   creates workload identity, AKS namespace RBAC, and the cluster-state PR.
5. The default namespace NetworkPolicy permits DNS and egress to the configured
   allowlisted CIDRs only on approved ports. The default port set covers HTTPS
   (`443`), PostgreSQL Flexible Server (`5432`), and Service Bus AMQP (`5671`);
   extra ports require a platform-reviewed vending change or egress exception.
   The policy still denies same-namespace pod-to-pod ingress. Multi-pod apps
   need a platform-reviewed NetworkPolicy or egress exception.

## AKS microservice

1. Confirm the target namespace has reconciled in cluster state.
2. Run `aks-microservice` with the vended namespace and language choice.
   The workload service account must match the namespace vending request; the
   default `app` creates both `app` and `helm-app` for the generated
   HelmRelease. Helm release state is stored outside the workload namespace in
   `helm-<namespace>` so chart templates cannot read application
   secrets.
3. Platform reviewers create the target repository from the generated request and
   confirm the component-specific folder under
   `golden-path-requests/aks/<team>/<component>` has `catalog-info.yaml`,
   `slo.yaml`, TechDocs, Helm chart, branch protection, CODEOWNERS, and
   `.github/workflows/ci.yml`.
4. The first push to `main` builds and signs the image, publishes the Helm chart,
   publishes TechDocs, and opens a GitOps PR into the namespace workloads path.
5. After the GitOps PR merges, verify `/healthz` returns `200 OK` and SLO alerts
   include `runbook_url`.

## ACA service

1. Confirm protected GitHub Environment variables are set:
   `PLATFORM_ACA_ENVIRONMENT_ID`, `PLATFORM_RESOURCE_GROUP_NAME`,
   `PLATFORM_LOCATION`, `PLATFORM_ACR_ID`, and `PLATFORM_ACR_LOGIN_SERVER`.
2. Run `aca-service` with the language, scale rule, and public route setting.
   Platform reviewers create the target repository from the generated request
   under `golden-path-requests/aca/<team>/<component>` and configure protected
   environment variables before merging application code.
   Queue scaling requires platform-owned protected variables
   `PLATFORM_ACA_QUEUE_NAME`, `PLATFORM_ACA_QUEUE_STORAGE_ACCOUNT_NAME`, and
   `PLATFORM_ACA_QUEUE_STORAGE_ACCOUNT_ID` so teams cannot grant themselves
   access to arbitrary storage accounts.
3. Store `APPLICATIONINSIGHTS_CONNECTION_STRING` as a repository secret only when
   the service exports Application Insights telemetry. The workflow stores it as
   an ACA secret reference instead of Terraform state or plain app config.
4. The first push to `main` builds and signs the image, applies the Terraform app
   resource, verifies the digest, and updates the Container App revision.
5. Validate the public FQDN when enabled and confirm the KQL pack returns data.
   The Stage 04 managed environment is internal; internet reachability requires
   the platform ingress/Front Door route in front of the ACA endpoint.
   The `demo` profile may deploy the ACA managed environment without Azure
   Firewall egress to keep MVP costs low; non-demo profiles still require the
   Stage 03 firewall route.

## Failure handling

| Symptom | Action |
| --- | --- |
| Template task denied | Confirm the user's Entra group is listed in `BACKSTAGE_APPLICATION_TEAM_GROUP_REFS` and mapped in `BACKSTAGE_APPLICATION_TEAM_GROUP_MAP`. |
| Generated repo CI cannot push ACR | Confirm GitHub Environment OIDC variables and self-hosted runner connectivity to private ACR. |
| GitOps PR has placeholder digest | Re-run the workflow; `gitops-push.yml` replaces image and chart digest placeholders only when `image_digest_ref` and `chart_digest_ref` are provided. |
| ACA update fails signature verification | Confirm the trusted workflow identity matches the generated repository workflow path. |
| Missing mandatory tags | Fix the generated tags in Helm values or Terraform variables; do not bypass policy. |
| AKS workload needs extra FQDN egress | Use the Stage 10 egress-exception template; application teams must not author Cilium egress policies directly. |
| AKS workload needs different NetworkPolicy | Open a platform-reviewed vending or egress-exception PR; tenant charts do not own NetworkPolicy resources. |
