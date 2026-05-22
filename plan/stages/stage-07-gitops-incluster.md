# Stage 07 — GitOps & in-cluster platform

## Goal

Make the AKS cluster a fully-featured platform: GitOps-reconciled, with
identity, secrets, certs, DNS, policy, and observability addons installed
and wired together.

## Scope (in)

### Flux

- Install via **AKS GitOps extension** (Microsoft-managed).
- One root Flux Kustomization per environment pointing at
  `platform-cluster-state/clusters/overlays/<env>` (separate repo,
  bootstrapped in Stage 04).
- Verify the `platform-cluster-state` repo exists with the seed `clusters/_base`
  and per-env overlay layout; **first deliverable of this stage** is to
  confirm and document this dependency.
- Multi-tenant Flux ([upstream guide][flux-mt]) with `Kustomization` /
  `HelmRelease` resources isolated per namespace using
  `--default-service-account` and tenant impersonation; cross-tenant
  references are rejected.
- **Image automation** for dev overlay only (Stage 06 ADR-0016).

[flux-mt]: https://fluxcd.io/flux/installation/configuration/multitenancy/

### Identity & secrets

- **Workload Identity** federation pre-wired on all platform SAs.
- **Secrets Store CSI driver** + Key Vault provider (default).
- **External Secrets Operator** (ESO) installed as an alternative for apps
  that need K8s `Secret` objects.
- `docs/runbooks/secret-rotation.md` defines the rotation contract every
  golden-path service signs: rotation period, owner, reload signal (SIGHUP /
  pod restart / re-mount).

### Certs & DNS

- **cert-manager** with two issuers:
  - **Let's Encrypt** (DNS-01 via Azure DNS) for public hostnames.
  - **Key Vault-backed private CA** — a `ClusterIssuer` of type `ca` whose
    signing cert + key are mounted via the **Secrets Store CSI driver**
    from the platform Key Vault (`ca.crt` + `ca.key`). This is **not**
    the deprecated `cert-manager-csi-driver` (different project), and
    not the cert-manager Azure issuer (no first-party KV issuer for
    cert-manager today). Rotation = rotate KV secret + restart
    cert-manager.
- **external-dns** integrated with Azure Public DNS + Private DNS zones.
  Default record types: `A` (and `AAAA` only when IPv6 ingress is enabled).
- Wildcard policy: per-cluster wildcard for `*.<env>.platform.<root-domain>`;
  per-team certs for product-owned hostnames.

### Policy

- **Kyverno** is the **only** in-cluster admission engine. The Stage 02
  `aks-baseline` initiative explicitly does **not** install the Azure
  Policy for AKS add-on (Gatekeeper) — this avoids dual-admission
  conflicts and resource pressure.
- Kyverno with policy bundle from `policies/kyverno/`:
  - Verify cosign signatures (mandatory in nonprod/prod).
  - Require labels: `app`, `team`, `costCenter`, `dataClassification`.
  - Forbid `:latest`, enforce resource requests/limits, disallow privileged.
  - **Generate** a default `NetworkPolicy` (deny-all + egress allowlist
    reference) in every namespace via Kyverno `generate` rules, plus a
    `validate` rule that fails admission if a namespace lacks one after
    the generator has run (rather than enforcing at pure admission time
    where the policy resource doesn't yet exist).
  - Enforce PodSecurity `restricted` per namespace.
- **Pod Security Admission** cluster-wide baseline; namespaces opt into
  `restricted`.
- **Gatekeeper not used** — Kyverno is the single in-cluster policy engine
  (ADR-0036).

### Azure Service Operator (ASO) v2

- Installed cluster-wide via Helm with the **`crdPattern`** Helm value
  set to the curated allowlist (e.g.
  `crdPattern: "servicebus.azure.com/*;keyvault.azure.com/*;dbforpostgresql.azure.com/*;storage.azure.com/*"`)
  so only the allowlisted CRDs are reconciled. The allowlist covers:
  KV secrets, Service Bus topics/subscriptions, Storage containers,
  Postgres databases/roles.
- Resource ownership boundary enforced via the `managedBy: aso` tag on every
  resource ASO creates.
- Example real CRD (note correct GVK):

  ```yaml
  apiVersion: servicebus.azure.com/v1api20211101
  kind: NamespacesTopic
  metadata:
    name: my-topic
    namespace: team-payments
  spec:
    owner:
      name: sb-pe-nonprod-eastus2
    azureName: my-topic
  ```

### Autoscaling addons

- **KEDA** installed via Flux (cluster-wide), to be used by golden-path
  templates for event-driven workloads. Stage 08 owns the *patterns*; the
  *install* lives here.

### Observability addons

- **Managed Prometheus** (Azure Monitor managed service) — DataCollectionRule
  + ConfigMap selectors. OTel pipeline writes to Managed Prom via the
  Azure Monitor Agent (AMA) sidecar pattern or **Prometheus remote-write**
  to the AMW ingestion endpoint, whichever is GA in the chosen region.
- **Managed Grafana** — workspace, role assignments, dashboards-as-code from
  `clusters/_base/observability/dashboards/`.
- **Container Insights** — Log Analytics agent, structured logs.
- **OpenTelemetry Collector** topology:
  - **DaemonSet** — host-level scraping, node logs (`filelog` receiver).
  - **Deployment** (tail-sampling layer) — receives OTLP from app pods,
    applies tail-based sampling for prod, fans out to Managed Prom +
    Application Insights + Log Analytics.
  - The two are non-overlapping; app pods always send to the Deployment.

### Ingress (continued from Stage 04)

- ingress-nginx Helm chart deployed via Flux.
- ExternalDNS records auto-created from `Ingress` resources.

## Scope (out)

- Service mesh (deferred, ADR-0004).
- Backstage itself (Stage 09).

## Deliverables

- All addons installed via Flux from `platform-cluster-state/clusters/_base/`.
- `policies/kyverno/` bundle with at least 10 baseline policies.
- `docs/runbooks/secret-rotation.md` — rotation contract.
- `docs/runbooks/cert-management.md` — issuer choice flowchart.
- `docs/adr/0004-no-mesh.md` — explicit "no mesh at MVP" decision.
- `docs/adr/0005-aso-boundary.md` — ASO/TF ownership boundary.

## Dependencies

- Stage 04 (AKS, KV, ACR), Stage 06 (signed images for verify).

## Decisions / ADRs

- **ADR-0004** No service mesh at MVP.
- **ADR-0005** ASO v2 with curated allowlist + ownership tag.
- **ADR-0006** Default secrets driver = Secrets Store CSI; ESO when K8s
  Secret objects required.
- **ADR-0036** Kyverno is the single in-cluster policy engine.

## Technologies

| Concern | Choice |
|---------|--------|
| GitOps | Flux (AKS extension) |
| Identity | Workload Identity + federated SA |
| Secrets | KV CSI (default) + ESO (alternative) |
| Certs | cert-manager + Let's Encrypt + KV-backed CA `ClusterIssuer` (CSI-mounted) |
| DNS | external-dns + Azure DNS |
| Policy | Kyverno + PSA (Kyverno is the single admission engine; AKS Policy add-on disabled) |
| Cloud resources from K8s | ASO v2 (`crdPattern` curated CRDs) |
| Event-driven autoscaling | KEDA |
| Metrics | Managed Prometheus |
| Dashboards | Managed Grafana |
| Logs | Container Insights → LA |
| Traces | OTel Collector → App Insights |

## Acceptance criteria

1. Flux reconciles a "hello" Kustomization in < 5 min from a PR-merge in
   `platform-cluster-state`. The **Stage-05 namespace-vending cross-stage
   gate** is validated here: a Kustomization created by Stage-05's
   `vend-namespace.yml` reconciles successfully.
2. Unsigned images are blocked by Kyverno verify; missing labels fail
   admission.
3. cert-manager issues a wildcard cert for `*.demo.platform.<root>` via
   Let's Encrypt and a private cert via the KV-backed CA `ClusterIssuer`;
   external-dns publishes the records.
4. ASO can create a Service Bus topic in the Stage-04 namespace from a
   `servicebus.azure.com/v1api20211101 NamespacesTopic` CR, and the
   resource carries `managedBy: aso`.
5. Managed Prometheus scrapes the cluster's `kube-system` metrics; Managed
   Grafana shows them. OTel Deployment forwards traces; Application
   Insights shows them.
6. KEDA is installed and a smoke-test ScaledObject scales a sample
   deployment based on a Service Bus queue length.
7. The `aks-baseline` initiative (Stage 02) is confirmed to have the AKS
   Policy add-on disabled; only Kyverno appears in cluster admission
   webhooks.

## Risks

- **Kyverno cluster-policy resource pressure** at scale → mutation policies
  tuned; admission timeout monitored.
- **cert-manager + Azure DNS rate limits** during cert burst → rate-limited
  issuer retry; long-lived wildcard preferred over per-host certs.
- **ASO CRD evolution** → curated allowlist limits blast radius; monthly
  upgrade PR.
- **OTel collector resource cost** → DaemonSet sized small; Deployment
  scales horizontally.
