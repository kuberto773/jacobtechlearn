# --------------------
# Resource Group for App Service resources
# --------------------

module "app_rg" {
  source   = "Azure/avm-res-resources-resourcegroup/azurerm"
  name     = "rg-${var.prefix}-${var.env}"
  location = var.region
  tags = {
    env = var.env
  }
}

# --------------------
# Resource Group for ACR
# --------------------

module "shared_rg" {
  source   = "Azure/avm-res-resources-resourcegroup/azurerm"
  name     = "rg-shared"
  location = var.region
}

# --------------------
# Log Analytics Workspace (AVM)
# --------------------
module "log_analytics" {
  source = "Azure/avm-res-operationalinsights-workspace/azurerm"

  resource_group_name                       = module.app_rg.name
  location                                  = var.region
  name                                      = "law-${var.prefix}-${var.env}"
  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_retention_in_days = 30
  log_analytics_workspace_internet_ingestion_enabled = true
  log_analytics_workspace_internet_query_enabled = true
  tags = {
    env = "devl"
  }
}

# --------------------
# Application Insights (AVM)
# --------------------
module "app_insights" {
  source = "Azure/avm-res-insights-component/azurerm"

  resource_group_name = module.app_rg.name
  location            = var.region
  name                = "appi-${var.prefix}-${var.env}"
  workspace_id        = module.log_analytics.resource_id
  application_type    = "web"
  tags = {
    env = "devl"
  }
}

# --------------------
# Azure Container Registry (AVM)
# --------------------
module "acr" {
  source = "Azure/avm-res-containerregistry-registry/azurerm"

  resource_group_name     = module.shared_rg.name
  location                = var.region
  name                    = "${var.prefix}acr"
  sku                     = var.acr_sku
  admin_enabled           = false
  zone_redundancy_enabled = false
}

# --------------------
# User Assigned Managed Identity (AVM)
# --------------------
module "uami" {
  source = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"

  resource_group_name = module.app_rg.name
  location            = var.region
  name                = "uami-${var.prefix}-${var.env}"
  tags = {
    env = "devl"
  }
}

# --------------------
# Role assignment: give the UAMI AcrPull access on the ACR
# --------------------
module "acr_role_assignment" {
  source = "Azure/avm-res-authorization-roleassignment/azurerm"

  role_assignments_azure_resource_manager = {
    acrpull = {
      role_definition_name = "AcrPull"
      principal_id         = module.uami.principal_id
      scope                = module.acr.resource_id
    }
  }
}

# --------------------
# App Service Plan (AVM) — Linux, F1
# --------------------
module "app_service_plan" {
  source = "Azure/avm-res-web-serverfarm/azurerm"

  resource_group_name    = module.app_rg.name
  location               = var.region
  name                   = "${var.prefix}-asp"
  os_type                = var.service_plan.os_type
  sku_name               = var.service_plan.sku
  zone_balancing_enabled = false

  tags = {
    env = "devl"
  }
}

# --------------------
# Web App (App Service) (AVM) — runs custom container from the ACR
# We attach the UAMI (user-assigned identity) to the web app and configure the container image
# --------------------
module "web_app" {
  source                      = "Azure/avm-res-web-site/azurerm"
  version                     = "0.19.0"
  kind                        = "webapp"
  location                    = var.region
  name                        = "app-${var.prefix}-${var.env}"
  os_type                     = var.service_plan.os_type
  resource_group_name         = module.app_rg.name
  service_plan_resource_id    = module.app_service_plan.resource_id
  enable_application_insights = false
  managed_identities = {
    user_assigned_resource_ids = [module.uami.resource_id]
  }
  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY             = "${module.app_insights.instrumentation_key}"
    ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
    DOCKER_ENABLE_CI                           = "true" # enable automatic image pull if new version is detected
  }

  logs = {
    app = {
      application_logs = {
        app = {
          file_system_level = "Verbose"
        }
      }
      http_logs = {
        app = {
          file_system = {
            retention_in_days = 7
            retention_in_mb   = 35
          }
        }
      }
      disk_quota_mb           = 50
      detailed_error_messages = true
      failed_request_tracing  = true
    }
  }
  site_config = {
    always_on                                     = true
    use_32_bit_worker                             = true
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = module.uami.client_id
    application_stack = {
      docker = {
        docker_image_name   = "${var.container_image}:${var.container_tag}"
        docker_registry_url = "https://${var.prefix}acr.azurecr.io"
      }
    }
  }

  tags = {
    env = "devl"
  }
}
