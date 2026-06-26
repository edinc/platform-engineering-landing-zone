locals {
  identity_name             = "id-pe-${var.environment}-${var.team_name}-${var.namespace}"
  flux_service_account_name = "tenant-${var.team_name}-${var.environment}-${var.namespace}"
  helm_service_account_name = "helm-${var.service_account_name}"
  helm_storage_namespace    = "helm-${var.namespace}"

  # The platform stack registers the cluster-state Flux source as
  # azurerm_kubernetes_flux_configuration "platform-<profile>" (profile == environment),
  # so the tenant Kustomization must reference platform-<environment> rather than a
  # static name. var.flux_source_name overrides this for non-standard clusters.
  flux_source_name = var.flux_source_name != "" ? var.flux_source_name : "platform-${var.environment}"

  labels = merge(
    var.extra_labels,
    {
      "app.kubernetes.io/managed-by"            = "platform-vending"
      "platform.example.io/team"                = var.team_name
      "platform.example.io/product"             = var.product
      "platform.example.io/environment"         = var.environment
      "platform.example.io/cost-center"         = var.cost_center
      "platform.example.io/data-classification" = var.data_classification
      "pod-security.kubernetes.io/audit"        = "restricted"
      "pod-security.kubernetes.io/enforce"      = "restricted"
      "pod-security.kubernetes.io/warn"         = "restricted"
    }
  )

  annotations = {
    "platform.example.io/on-call" = var.on_call_rotation_id
  }

  output_root = startswith(var.output_directory, "/") ? var.output_directory : "${path.module}/${var.output_directory}"

  parent_output_directory    = abspath("${local.output_root}/tenants/${var.team_name}/${var.environment}")
  tenant_output_directory    = "${local.parent_output_directory}/${var.namespace}"
  namespace_output_directory = "${local.tenant_output_directory}/bootstrap"
  workload_output_directory  = "${local.tenant_output_directory}/workloads"

  manifests = {
    "namespace.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "Namespace"
      metadata = {
        name        = var.namespace
        labels      = local.labels
        annotations = local.annotations
      }
    })

    "resourcequota.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "ResourceQuota"
      metadata = {
        name        = "rq-${var.namespace}"
        namespace   = var.namespace
        labels      = local.labels
        annotations = local.annotations
      }
      spec = {
        hard = {
          "requests.cpu"    = var.resource_quota.cpu_requests
          "requests.memory" = var.resource_quota.memory_requests
          "limits.cpu"      = var.resource_quota.cpu_limits
          "limits.memory"   = var.resource_quota.memory_limits
          pods              = tostring(var.resource_quota.pods)
        }
      }
    })

    "rbac.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "RoleBinding"
      metadata = {
        name        = "rb-${var.namespace}-team-edit"
        namespace   = var.namespace
        labels      = local.labels
        annotations = local.annotations
      }
      subjects = [
        {
          kind     = "Group"
          apiGroup = "rbac.authorization.k8s.io"
          name     = var.entra_group_object_id
        }
      ]
      roleRef = {
        kind     = "ClusterRole"
        apiGroup = "rbac.authorization.k8s.io"
        name     = "view"
      }
    })

    "networkpolicy-egress-allowlist.yaml" = yamlencode({
      apiVersion = "networking.k8s.io/v1"
      kind       = "NetworkPolicy"
      metadata = {
        name        = "egress-allowlist"
        namespace   = var.namespace
        labels      = local.labels
        annotations = local.annotations
      }
      spec = {
        podSelector = {}
        policyTypes = ["Egress", "Ingress"]
        ingress = [
          {
            from = [
              {
                namespaceSelector = {
                  matchLabels = {
                    "kubernetes.io/metadata.name" = "ingress-nginx"
                  }
                }
              },
              {
                namespaceSelector = {
                  matchLabels = {
                    "kubernetes.io/metadata.name" = "observability"
                  }
                }
              },
              {
                namespaceSelector = {
                  matchLabels = {
                    "kubernetes.io/metadata.name" = "kube-system"
                  }
                }
              },
            ]
          }
        ]
        egress = [
          {
            to = [
              {
                namespaceSelector = {
                  matchLabels = {
                    "kubernetes.io/metadata.name" = "kube-system"
                  }
                }
              }
            ]
            ports = [
              {
                protocol = "UDP"
                port     = 53
              },
              {
                protocol = "TCP"
                port     = 53
              },
            ]
          },
          {
            to = [
              for cidr in var.egress_allowlist_cidrs : {
                ipBlock = {
                  cidr = cidr
                }
              }
            ]
            ports = [
              for allowed in var.egress_allowlist_ports : {
                protocol = allowed.protocol
                port     = allowed.port
              }
            ]
          }
        ]
      }
    })

    "serviceaccount.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name      = var.service_account_name
        namespace = var.namespace
        labels    = merge(local.labels, { "azure.workload.identity/use" = "true" })
        annotations = merge(local.annotations, {
          "azure.workload.identity/client-id" = azurerm_user_assigned_identity.workload.client_id
        })
      }
    })

    "flux-serviceaccount.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name      = local.flux_service_account_name
        namespace = "flux-system"
        labels    = local.labels
      }
    })

    "flux-rolebinding.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "RoleBinding"
      metadata = {
        name        = "rb-${var.namespace}-flux-reconciler"
        namespace   = var.namespace
        labels      = local.labels
        annotations = local.annotations
      }
      subjects = [
        {
          kind      = "ServiceAccount"
          name      = local.flux_service_account_name
          namespace = "flux-system"
        }
      ]
      roleRef = {
        kind     = "ClusterRole"
        apiGroup = "rbac.authorization.k8s.io"
        name     = "platform:tenant-flux-reconciler"
      }
    })

    "helm-serviceaccount.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name        = local.helm_service_account_name
        namespace   = var.namespace
        labels      = local.labels
        annotations = local.annotations
      }
    })

    "helm-storage-namespace.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "Namespace"
      metadata = {
        name        = local.helm_storage_namespace
        labels      = local.labels
        annotations = local.annotations
      }
    })

    "helm-storage-rolebinding.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "RoleBinding"
      metadata = {
        name        = "rb-${var.namespace}-helm-storage"
        namespace   = local.helm_storage_namespace
        labels      = local.labels
        annotations = local.annotations
      }
      subjects = [
        {
          kind      = "ServiceAccount"
          name      = local.helm_service_account_name
          namespace = var.namespace
        }
      ]
      roleRef = {
        kind     = "ClusterRole"
        apiGroup = "rbac.authorization.k8s.io"
        name     = "platform:tenant-helm-release-storage"
      }
    })

    "helm-rolebinding.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "RoleBinding"
      metadata = {
        name        = "rb-${var.namespace}-helm-reconciler"
        namespace   = var.namespace
        labels      = local.labels
        annotations = local.annotations
      }
      subjects = [
        {
          kind      = "ServiceAccount"
          name      = local.helm_service_account_name
          namespace = var.namespace
        }
      ]
      roleRef = {
        kind     = "ClusterRole"
        apiGroup = "rbac.authorization.k8s.io"
        name     = "platform:tenant-flux-reconciler"
      }
    })

    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "namespace.yaml",
        "resourcequota.yaml",
        "rbac.yaml",
        "networkpolicy-egress-allowlist.yaml",
        "serviceaccount.yaml",
        "flux-serviceaccount.yaml",
        "flux-rolebinding.yaml",
        "helm-serviceaccount.yaml",
        "helm-storage-namespace.yaml",
        "helm-storage-rolebinding.yaml",
        "helm-rolebinding.yaml",
      ]
    })
  }

  flux_kustomization = yamlencode({
    apiVersion = "kustomize.toolkit.fluxcd.io/v1"
    kind       = "Kustomization"
    metadata = {
      name        = "tenant-${var.team_name}-${var.environment}-${var.namespace}"
      namespace   = "flux-system"
      labels      = local.labels
      annotations = local.annotations
    }
    spec = {
      interval           = "5m"
      prune              = true
      serviceAccountName = local.flux_service_account_name
      wait               = true
      path               = "./tenants/${var.team_name}/${var.environment}/${var.namespace}/workloads"
      sourceRef = {
        kind = "GitRepository"
        name = local.flux_source_name
      }
    }
  })
}
