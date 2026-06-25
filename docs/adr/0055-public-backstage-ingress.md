# ADR-0055: Dedicated public Backstage ingress for demo access

- Status: accepted
- Date: 2026-06-23
- Stage: Stage 09 - Backstage MVP

## Context

The platform AKS cluster and default ingress controller are private. This keeps
the platform control plane isolated, but it also means operators cannot reach the
demo Backstage portal from a normal workstation unless they have private network
connectivity into the platform VNet.

The request is to expose only Backstage publicly while keeping AKS, platform
controllers, and other in-cluster services private.

## Decision

Expose Backstage through a dedicated public `ingress-nginx` controller in the
demo overlay. The existing private `ingress-nginx` controller and private
Backstage Ingress remain unchanged.

Terraform creates a static Standard public IP when
`enable_backstage_public_ingress` is true and grants the AKS control-plane
managed identity Network Contributor on that public IP. Enabling public access
means the demo Backstage sign-in page is reachable from the internet. Access is
gated by Microsoft Entra ID and Backstage RBAC instead of client source IPs,
because browser egress addresses change frequently in demo and remote-work
scenarios. Flux passes the public IP name, resource group, and DNS label host
into the demo addon overlay. Terraform outputs the Microsoft Entra redirect URI
that must be added to the externally supplied Backstage app registration. When
public Backstage ingress is disabled, the public controller
reconciles to zero replicas and has no LoadBalancer Service.
The public route resources are reconciled by a separate wait-free Flux
Kustomization so certificate issuance cannot block private Backstage rollout.

Only the `ingress-nginx-public` namespace is watched by the public controller,
and only the `backstage-public` IngressClass is used for the public route. The
public Backstage Ingress and default TLS certificate both live in
`ingress-nginx-public`, while the backend service is an `ExternalName` service
that resolves to the private `backstage.backstage.svc.cluster.local` service.
That avoids granting the internet-facing controller read access to Backstage
runtime secrets. When no custom domain is available, the certificate uses an
HTTP-01 Let's Encrypt issuer and the Azure public IP DNS-label FQDN
`<label>.<region>.cloudapp.azure.com`. The public LoadBalancer remains reachable
on ports 80 and 443 so ACME HTTP-01 challenges can complete, but the Backstage
application still requires Entra-backed sign-in and Backstage RBAC.
Terraform also opens ports 80 and 443 on the AKS user-pool subnet NSG when the
public ingress is enabled; otherwise the platform-owned subnet NSG denies client
traffic after Azure Load Balancer forwards it to the nodes.

## Consequences

- Backstage is reachable from the internet and gated by Entra ID sign-in plus
  Backstage RBAC without exposing the AKS API server or the private platform
  ingress controller.
- The public ingress remains GitOps-managed and can be disabled through the
  Terraform variable.
- Entra group membership and Backstage RBAC become the access-control boundary
  for the public demo route.
- Disabling public access removes the public LoadBalancer Service path through
  Helm reconciliation rather than suspending Flux.
- The inert public Ingress, backend service, and public TLS Certificate objects
  may remain when public access is disabled. Cert-manager may still retain or
  renew the TLS Secret because the manifest is present in the demo overlay.
- The public LoadBalancer must accept internet traffic for ACME HTTP-01
  validation and the Backstage sign-in page.
- The public ingress controller runs in a separate namespace and is excluded from
  platform Kyverno controller-image policies for the same reason as the private
  ingress controller.

## Alternatives considered

| Alternative | Reason not chosen |
|-------------|-------------------|
| Make the existing private ingress controller public | Would expose any current or future private Ingress reconciled by that controller. |
| Public AKS API or kubeconfig access | Exposes the control plane instead of only Backstage. |
| Azure Front Door/App Gateway first | Better long-term edge posture, but heavier than the requested demo-only public Backstage access. |

## References

- [`platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml`](../../platform-gitops/clusters/overlays/demo/addon-config/ingress-nginx-public.yaml)
- [`platform-gitops/clusters/overlays/demo/public-backstage/public-ingress.yaml`](../../platform-gitops/clusters/overlays/demo/public-backstage/public-ingress.yaml)
- [`infrastructure/terraform/platform/backstage-public-ingress.tf`](../../infrastructure/terraform/platform/backstage-public-ingress.tf)
