data "azurerm_resource_group" "tclo" {
  name = var.resource_group_name
}

data "azurerm_dev_test_lab" "tclo" {
  name                = var.devtestlab_name
  resource_group_name = data.azurerm_resource_group.tclo.name
}

resource "azurerm_dev_test_linux_virtual_machine" "vmapp" {
  name                   = "deplinux-test"
  lab_name               = data.azurerm_dev_test_lab.tclo.name
  resource_group_name    = data.azurerm_resource_group.tclo.name
  location               = var.location
  size                   = "Standard_A4_v2"
  username               = var.username_app
  password               = var.password_app
  ssh_key                = file("./ssh/id_ed25519.pub")
  lab_virtual_network_id = var.lab_virtual_network_id
  lab_subnet_name        = var.lab_subnet_name
  storage_type           = "Standard"
  notes                  = "TCLO TERRAFORM VMs"
  allow_claim            = false

  gallery_image_reference {
    offer     = "0001-com-ubuntu-server-jammy"
    publisher = "Canonical"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    environment = "development"
  }
  
    provisioner "local-exec" {
    command = <<EOT
    host_entry=${azurerm_dev_test_linux_virtual_machine.vmapp.fqdn}

    if [ -z "$host_entry" ]; then
    echo "Error: FQDN is not available." >&2
    exit 1
    fi

    cat <<EOF > ./ansible/inventories/hosts.yml
    all:
    hosts:
        vmapp:
        ansible_host: $host_entry
        ansible_user: ${var.username_app}
        ansible_password: ${var.password_app}
    EOF
    EOT
    }

}


