data "azurerm_resource_group" "example" {
  name = var.resource_group_name
}

# Récupération de l'app registration name
data "azuread_application" "appregistration" {
  display_name = var.app_registration_name
}

# Récupérer le DevTest Lab existant
#data "azurerm_dev_test_lab" "devtestlab" {
#  name                = var.devtestlab_name
#  resource_group_name = var.resource_group_name
#}


# Generate a random integer to create a globally unique name
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}


# Création d'un App Service Plan
resource "azurerm_service_plan" "appserviceplan" {
  name                = "webapp-asp-${random_integer.ri.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "B1"
}

# Création de la Web App 
resource "azurerm_linux_web_app" "webapp" {
  name                = "webapp-${random_integer.ri.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id = azurerm_service_plan.appserviceplan.id
  https_only            = true
  site_config { 
    minimum_tls_version = "1.2"
    application_stack {
      php_version = "8.2" # Change to appropiate application and version
    }
  }
}

#  Deploy code from a public GitHub repo
resource "azurerm_app_service_source_control" "sourcecontrol" {
  app_id             = azurerm_linux_web_app.webapp.id
  repo_url           = var.source_control_repo_url
  branch             = "main"
  use_manual_integration = false
  use_mercurial      = false
}

resource "azurerm_source_control_token" "source_control_token" {
  type         = "GitHub"
  token        = var.github_auth_token
  token_secret = var.github_auth_token
}