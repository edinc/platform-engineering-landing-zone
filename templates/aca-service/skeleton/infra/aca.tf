locals {
  container_app_name = "ca-${var.component_id}-${var.environment}"
  queue_resource_id = (
    var.queue_storage_account_id != "" && var.queue_name != "" ?
    "${var.queue_storage_account_id}/queueServices/default/queues/${var.queue_name}" :
    ""
  )
}

resource "terraform_data" "input_guard" {
  input = {
    scale_rule                 = var.scale_rule
    queue_name                 = var.queue_name
    queue_storage_account_name = var.queue_storage_account_name
    queue_storage_account_id   = var.queue_storage_account_id
  }

  lifecycle {
    precondition {
      condition = (
        var.scale_rule != "queue" ||
        alltrue([
          var.queue_name != "",
          var.queue_storage_account_name != "",
          var.queue_storage_account_id != "",
        ])
      )
      error_message = "scale_rule = queue requires queue_name, queue_storage_account_name, and queue_storage_account_id."
    }
  }
}

resource "azurerm_user_assigned_identity" "workload" {
  name                = "id-${var.component_id}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "queue_reader" {
  count = var.scale_rule == "queue" ? 1 : 0

  scope                = local.queue_resource_id
  role_definition_name = "Storage Queue Data Reader"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_container_app" "this" {
  name                         = local.container_app_name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.workload.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.workload.id
  }

  ingress {
    external_enabled = var.public_route
    target_port      = var.container_port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = 0
    max_replicas = var.max_replicas

    container {
      name   = "app"
      image  = var.image_digest
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "PORT"
        value = tostring(var.container_port)
      }

      env {
        name  = "OTEL_SERVICE_NAME"
        value = var.component_id
      }

    }

    dynamic "http_scale_rule" {
      for_each = var.scale_rule == "http" ? [1] : []

      content {
        name                = "http"
        concurrent_requests = 50
      }
    }

    dynamic "custom_scale_rule" {
      for_each = var.scale_rule == "queue" ? [1] : []

      content {
        name             = "queue-depth"
        custom_rule_type = "azure-queue"
        identity_id      = azurerm_user_assigned_identity.workload.id
        metadata = {
          accountName = var.queue_storage_account_name
          queueName   = var.queue_name
          queueLength = "10"
        }
      }
    }

    dynamic "custom_scale_rule" {
      for_each = var.scale_rule == "cron" ? [1] : []

      content {
        name             = "business-hours"
        custom_rule_type = "cron"
        metadata = {
          timezone        = "UTC"
          start           = "0 8 * * 1-5"
          end             = "0 18 * * 1-5"
          desiredReplicas = "1"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].container[0].image,
    ]
  }

  depends_on = [
    terraform_data.input_guard,
    azurerm_role_assignment.acr_pull,
    azurerm_role_assignment.queue_reader,
  ]
}
