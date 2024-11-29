data "azurerm_resource_group" "example" {
  name = var.resource_group_name
}
 
# Récupérer le DevTest Lab existant
data "azurerm_dev_test_lab" "example" {
  name                = var.devtestlab_name
  resource_group_name = data.azurerm_resource_group.example.name
}


resource "azurerm_dev_test_linux_virtual_machine" "vmapp" {
  name                   = "Linux-app"
  lab_name               = data.azurerm_dev_test_lab.example.name
  resource_group_name    = data.azurerm_resource_group.example.name
  location               = var.location
  size                   = "Standard_A4_v2"    
  username               = var.username-app
  password               = var.password-app   
  lab_virtual_network_id = var.lab_virtual_network_id
  lab_subnet_name        = var.lab_subnet_name
  storage_type           = "Standard"      

  gallery_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

  resource "azurerm_dev_test_linux_virtual_machine" "vmsql" {
  name                   = "Linux-sql"
  lab_name               = data.azurerm_dev_test_lab.example.name
  resource_group_name    = data.azurerm_resource_group.example.name
  location               = var.location
  size                   = "Standard_A4_v2"    
  username               = var.username-sql
  password               = var.password-sql   
  lab_virtual_network_id = var.lab_virtual_network_id
  lab_subnet_name        = var.lab_subnet_name
  storage_type           = "Standard"      

  gallery_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

}





