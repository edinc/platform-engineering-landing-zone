# Platform Engineering Landing Zone

Opinionated Azure Platform Engineering Landing Zone for building a secure,
compliant, reusable Internal Developer Platform (IDP) in your Azure tenant and
subscriptions.

The product roadmap lives in [`plan/plan.md`](plan/plan.md). Detailed
implementation notes live in [`plan/stages/`](plan/stages/) for maintainers,
but day-to-day users should start with the workflow-driven deployment path
below.

## Current implementation

MVP with Backstage, GitOps, supply-chain workflows, team onboarding, namespace
vending, and three golden paths: AKS microservice, Azure Container Apps service,
and AKS workload namespace.

The repository has the workflow surface needed to deploy the Azure platform
substrate, publish Backstage artifacts, enable GitOps/Backstage, and exercise
the golden-path flow without committing tenant-specific tfvars.

## What this installs

| Capability | Outcome |
| --- | --- |
| Azure foundation | Remote Terraform state, OIDC-based GitHub deployment identity, seed Key Vault, diagnostics, and break-glass monitoring. |
| Subscription baseline | Activity Log diagnostics, Defender for Cloud posture, budgets, cost exports, and policy validation. |
| Connectivity | Hub/spoke networking, Private DNS, Private Endpoints, NAT/firewall-ready egress, and exception workflows. |
| Platform services | Private AKS, ACR, Key Vault, Service Bus, Container Apps environment, Front Door/WAF shell, and optional Postgres/TechDocs/cost allocator. |
| GitOps platform | Flux, cert-manager, external-dns, External Secrets, CSI Key Vault provider, ASO, Kyverno, KEDA, ingress-nginx, and observability add-ons. |
| Developer portal | Backstage with Entra auth, catalog, TechDocs, Kubernetes, Flux, GitHub Actions, Cost Insights, RBAC, and scaffolder templates. |
| Golden paths | AKS microservice, Azure Container Apps service, and AKS workload namespace templates with CI, signing, SBOMs, SLOs, docs, and ownership metadata. |

## Before you start

You need:

1. An Azure subscription where you can create role assignments and resource
   providers.
2. A GitHub repository created from this project, with GitHub Actions enabled.
3. A VNet-integrated self-hosted runner labeled
   `[self-hosted, azure, private-acr, swedencentral]`. The label set is fixed so
   protected jobs cannot be dispatched to arbitrary runners.
4. `az`, `gh`, Terraform, and the pinned local toolchain (`mise install`) for
   local validation and bootstrap recovery.
5. Protected GitHub Environments (`bootstrap`, `dev`, `nonprod`, `prod`) with
   deployment branch policies that allow only `main` for Azure-backed jobs.

## Customize your clone

Before opening the portal to application teams, set these organization-specific
values once:

| Value | Where to configure |
| --- | --- |
| GitHub owner/repository | Terraform `github_owner` / `github_repo`, Backstage Helm `appConfig.githubOrg` / `appConfig.platformRepositoryName` / `appConfig.platformRepositoryUrl`, and the trusted `githubOwner` / `platformRepo*` values in `templates/*/template.yaml`. |
| Platform DNS zone | Terraform `platform_root_domain` and Azure DNS resource group inputs. |
| Private runner labels | Workflow `runs-on` label set if your approved private runner is not `[self-hosted, azure, private-acr, swedencentral]`; update `scripts/workflows/validate_stage06_workflows.py` with the same approved label set. |
| Backstage runtime secrets | Platform Key Vault secret names listed in [`docs/runbooks/backstage-ops.md`](docs/runbooks/backstage-ops.md). |
| Team names | GitHub/Entra groups such as `pe-platform-admins`, `pe-platform-operators`, and `app-team-<team>`. |

The repository uses neutral placeholder owner/domain/team values where a value
cannot be inferred safely. Replace them before publishing Backstage templates to
developers.

## Workflow-driven deployment path

Use the existing workflows from `main`; do not run Terraform locally except for
recovery. Azure-backed jobs must use the VNet-integrated
self-hosted runner matching `[self-hosted, azure, private-acr, swedencentral]`
because Terraform state, ACR, Key Vault, AKS, and TechDocs storage are private.

1. **Bootstrap Azure foundation**: run **Bootstrap Azure foundation** with
   `action=apply`.
   This creates/repairs remote state, seed Key Vault, OIDC, state containers,
   and bootstrap monitoring.
2. **Deploy infrastructure stacks**: run **Deploy infrastructure stack** once
   per stack below. First run with `action=plan`, then rerun the same stack with
   `action=apply` after review. Set `environment=dev` for the demo profile
   unless you have split GitHub Environments per profile. Set `subscription_id`
   to the Azure subscription ID; it is used by the subscription-baseline state
   key and keeps dispatch input consistent across stacks. The reusable Terraform
   workflow remains `workflow_call` only; the deploy entrypoint maps approved
   stack choices to it from `main`.

   | Order | `stack` input | `tfvars_json_variable` |
   | --- | --- | --- |
   | 1 | `subscription-baseline` | `TERRAFORM_TFVARS_SUBSCRIPTION_BASELINE_JSON` |
   | 2 | `connectivity` | `TERRAFORM_TFVARS_CONNECTIVITY_JSON` |
   | 3 | `identity` | `TERRAFORM_TFVARS_IDENTITY_JSON` |
   | 4 | `cluster-state-repo` | `TERRAFORM_TFVARS_CLUSTER_STATE_REPO_JSON` |
   | 5 | `platform` | `TERRAFORM_TFVARS_PLATFORM_JSON` |

   Use `tfvars_json_secret` only for sensitive JSON such as a PostgreSQL
   password. The platform stack automatically reads
   `TERRAFORM_TFVARS_PLATFORM_SECRET_JSON` as its sensitive tfvars source. The
   workflow materializes these protected GitHub variable/secret values as
   temporary `*.auto.tfvars.json` files on the runner and removes them at the end
   of the job.
3. **Publish Backstage artifacts**: run **Backstage CI** on `main`. The
   workflow summary prints the Backstage image digest, catalog reconciler image
   digest, chart digest, and chart version.
4. **Enable GitOps, TechDocs, and Backstage**: update the protected
   `TERRAFORM_TFVARS_PLATFORM_JSON` with the Backstage CI summary values and set
   `enable_gitops=true`, `enable_techdocs_storage=true`, and
   `enable_backstage=true`; then rerun **Deploy infrastructure stack** for the
   `platform` stack. The platform stack creates the default cert-manager,
   external-dns, External Secrets, ASO, Backstage, and catalog-reconciler
   Workload Identity managed identities and federated credentials. Supply the
   corresponding `*_workload_identity_*` variables only when adopting existing
   identities; for brownfield add-on identities, the operator also owns the
   matching DNS/Key Vault RBAC grants.
5. **Seed Backstage runtime secrets** in the platform Key Vault from a
   VNet-connected runner/operator session before expecting pods to become ready:
   `backstage-session-secret`,
   `backstage-microsoft-auth-client-secret`, `backstage-github-app-id`,
   `backstage-github-app-client-id`, `backstage-github-app-client-secret`,
   `backstage-github-app-webhook-secret`, `backstage-github-app-private-key`,
   `backstage-catalog-reconciler-github-token`, and optionally
   `backstage-catalog-reconciler-teams-webhook-url`. If
   `backstage_postgres_auth_mode=password`, also seed
   `backstage-postgres-password`.
6. **Smoke the deployed platform**:
   - Run **Backstage CI** with `run_azure_smoke=true` to validate AKS Workload
     Identity, TechDocs storage, private endpoint wiring, and the Backstage
     readiness endpoint.
   - Run **Supply-chain smoke test** to build/sign the sample image.
     Set `run_nonprod_promotion=true` and `run_prod_promotion=true` only when
     disposable cluster-state Kustomize paths exist and environment approvals are
     ready.
   - Run **Onboard application team** and **Provision AKS namespace** with
     request YAMLs for the test team, merge the generated PRs, then use
     Backstage to create an AKS microservice and verify `/healthz`.

## Local setup

1. Create or switch to a task-specific feature branch.
2. Install the pinned toolchain with `mise install` or open the repository in
   the devcontainer.
3. Run `make bootstrap`.
4. Validate changes with:

   ```sh
   make lint validate policy-test-rego policy-test-kyverno
   ```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for contribution and review guidance.
