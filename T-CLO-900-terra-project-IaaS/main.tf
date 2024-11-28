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
   # Provisioner to upload the SSH key
  provisioner "file" {
    source      = "ssh-keys/id_rsa"
    destination = "/root/.ssh/id_rsa"

    connection {
      type        = "ssh"
      user        = var.username-app
      private_key = file("./ssh/id_rsa")
      host        = self.fqdn
    }
  }

  # Provisioner to run Ansible playbook
  provisioner "local-exec" {
    command = <<EOT
      ansible-playbook -i '${self.fqdn},' \
        -u ${var.username-app} \
        --private-key ~/.ssh/id_rsa \
        playbooks/setup-app.yml
    EOT
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
   provisioner "file" {
    source      = "ssh-keys/id_rsa"
    destination = "/root/.ssh/id_rsa"

    connection {
      type        = "ssh"
      user        = var.username-sql
      private_key = file("./ssh/id_rsa")
      host        = self.fqdn
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      ansible-playbook -i '${self.fqdn},' \
        -u ${var.username-sql} \
        --private-key ~/.ssh/id_rsa \
        playbooks/setup-sql.yml
    EOT
  }

}





