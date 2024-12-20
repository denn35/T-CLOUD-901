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
  app_settings = {
      #DOCKER_REGISTRY_SERVER_URL = "https://index.docker.io",
      WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false",
      DB_CONNECTION="mysql",
      DB_HOST="terracloud-mysqlserver.mysql.database.azure.com",
      DB_PORT=3306,
      DB_DATABASE="laravel",
      DB_USERNAME="root",
      DB_PASSWORD="root",
      MYSQL_ATTR_SSL_CA="/home/site/wwwroot/ssl/DigiCertGlobalRootCA.crt.pem",
      LOG_CHANNEL="stderr",
      APP_DEBUG=true,
      APP_KEY="base64:Dsz40HWwbCqnq0oxMsjq7fItmKIeBfCBGORfspaI1Kw="
  }  
  identity {
    type = "SystemAssigned"
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

#resource "azurerm_source_control_token" "source_control_token" {
#  type         = "GitHub"
#  token        = var.github_auth_token
#  token_secret = var.github_auth_token
#}

resource "azurerm_mysql_server" "terracloud_mysql" {
  name                = "terracloud-mysqlserver"
  location            = var.location
  resource_group_name = var.resource_group_name

  administrator_login          = "root"
  administrator_login_password = "root"

  sku_name   = "B_Gen5_2"
  version    = "8.0"


  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = true
  # infrastructure_encryption_enabled = true
  public_network_access_enabled     = false
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}

resource "azurerm_mysql_database" "terracloud_database" {
  name                = "terracloud-database"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_server.terracloud_mysql.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

output "app_url" {
   value = azurerm_linux_web_app.webappcontapp.default_hostname
}