variable "resource_group_name" {
  default = "t-clo-901-rns-0-items"
  type        = string
}

variable "location" {
  default = "WestEurope"
  type        = string
}

variable "app_registration_name" {
  default = "t-clo-901-rns-0"
  type        = string
}

variable "source_control_repo_url" {
  default = "https://github.com/denn35/T-CLOUD-901/tree/main/sample-app"
  type        = string
}

variable "devtestlab_name" {
  default = "t-clo-901-rns-0"
  type        = string
}

variable "lab_subnet_name" {
  default = "t-clo-901-rns-0Subnet"
  type        = string
}

variable "lab_virtual_network_id" {
  default = "/subscriptions/1eb5e572-df10-47a3-977e-b0ec272641e4/resourcegroups/t-clo-901-rns-0/providers/microsoft.devtestlab/labs/t-clo-901-rns-0/virtualnetworks/t-clo-901-rns-0"
  type        = string
}

variable "github_auth_token" {
  type        = string
  description = "Github Auth Token from Github > Developer Settings > Personal Access Tokens > Tokens Classic (needs to have repo permission)"
}
