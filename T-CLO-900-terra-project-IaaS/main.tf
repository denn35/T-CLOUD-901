# Data source: Resource group
data "azurerm_resource_group" "tclo" {
  name = var.resource_group_name
}

# Data source: DevTest Lab
data "azurerm_dev_test_lab" "tclo" {
  name                = var.devtestlab_name
  resource_group_name = data.azurerm_resource_group.tclo.name
}


# Create VM
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
}

# Define locals for FQDN and IP address
locals {
  # Vérification conditionnelle pour FQDN
  vm_fqdn = azurerm_dev_test_linux_virtual_machine.vmapp.fqdn
}

# Install python & ansible 
resource "null_resource" "setup_ansible" {
  provisioner "remote-exec" {
    inline = [
      "set -x",
      "export DEBIAN_FRONTEND=noninteractive",
      "echo dbus dbus/restart-services select polkit.service,walinuxagent.service | sudo debconf-set-selections",
      "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'Waiting for lock release...'; sleep 2; done",
      "sudo apt update",
      "sudo apt upgrade -y",
      "sudo apt install -y python3 python3-pip",
      "sudo apt install -y ansible-core",
      "sudo apt install -y ansible"
    ]


    connection {
      type        = "ssh"
      host        = local.vm_fqdn  # Ou utilisez `local.vm_ip_address` si nécessaire
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  depends_on = [azurerm_dev_test_linux_virtual_machine.vmapp]

}
# Step to upload the ansible directory to the remote machine
resource "null_resource" "upload_ansible" {
  provisioner "file" {
    source      = "./ansible"  # Local path to the ansible directory
    destination = "/home/${var.username_app}/ansible"  # Destination path on the remote VM

    connection {
      type        = "ssh"
      host        = local.vm_fqdn  # Or use local.vm_ip_address if necessary
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  depends_on = [null_resource.setup_ansible]
}

# Step to generate the inventory file
# Step to generate or update the inventory file
resource "null_resource" "generate_inventory" {
  provisioner "remote-exec" {
    inline = [
      "cd /home/${var.username_app}/ansible/inventories",
      "echo all: > hosts.yml",
      "echo \"  hosts:\" >> hosts.yml",
      "echo \"    slave1:\" >> hosts.yml",  # Correspond au nom utilisé dans le playbook
      "echo \"      ansible_host: ${local.vm_fqdn}\" >> hosts.yml",
      "echo \"      ansible_user: ${var.username_app}\" >> hosts.yml",
      "echo \"      ansible_password: ${var.password_app}\" >> hosts.yml"
    ]

    connection {
      type        = "ssh"
      host        = local.vm_fqdn  # Ou utilisez local.vm_ip_address si nécessaire
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  depends_on = [null_resource.upload_ansible]
}


# # Generate Ansible inventory
# resource "null_resource" "generate_inventory" {
#   provisioner "local-exec" {
#     command = <<EOT
# echo all: > ./ansible/inventories/hosts.yml
# echo "  hosts:" >> ./ansible/inventories/hosts.yml
# echo "    vmapp:" >> ./ansible/inventories/hosts.yml
# echo "      ansible_host: deplinux-test.westeurope.cloudapp.azure.com" >> ./ansible/inventories/hosts.yml
# echo "      ansible_user: appuser99" >> ./ansible/inventories/hosts.yml
# echo "      ansible_password: Pa$w0rd1234!" >> ./ansible/inventories/hosts.yml
# EOT
#   }

#   depends_on = [null_resource.setup_ansible]
# }





resource "null_resource" "run_playbook" {
  provisioner "remote-exec" {
    inline = [
      "ansible-playbook -i /home/${var.username_app}/ansible/inventories/hosts.yml /home/${var.username_app}/ansible/playbook.yml -vv > /tmp/playbook_output.txt 2>&1",
      "cat /tmp/playbook_output.txt"
    ]

    connection {
      type        = "ssh"
      host        = local.vm_fqdn  # Ou utilisez local.vm_ip_address si nécessaire
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  triggers = {
    playbook_result = uuid() # Générez un nouvel ID à chaque exécution pour forcer l'exécution
  }

  depends_on = [null_resource.generate_inventory]
}

resource "local_file" "playbook_output" {
  content = <<EOT
  ${null_resource.run_playbook.provisioner["remote-exec"][1]}
  EOT
  filename = "./playbook_output.txt"
}
