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

# Install Python and Ansible
resource "null_resource" "setup_ansible" {
  provisioner "remote-exec" {
    inline = [
    # Activer le mode strict et exporter la variable pour un mode non-interactif
      "set -eux",
      "export DEBIAN_FRONTEND=noninteractive",
      "echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections",
 
      # Attendre la libération du verrou dpkg s'il y en a un
      "while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do echo 'Waiting for dpkg lock release...'; sleep 2; done",
 
      # Installer needrestart et configurer le redémarrage automatique silencieux
      "sudo apt-get update -y",
      "sudo apt-get install -y needrestart",
      "sudo sed -i 's/^#\\$nrconf{restart} = .*/\\$nrconf{restart} = \"a\";/' /etc/needrestart/needrestart.conf",
 
      # Configuration temporaire pour apt pour éviter les redémarrages interactifs
      "sudo mkdir -p /etc/apt/apt.conf.d",
      "echo 'DPkg::Options { \"--force-confdef\"; \"--force-confold\"; }' | sudo tee /etc/apt/apt.conf.d/local",
 
      # Mise à jour et installation silencieuse des paquets nécessaires
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y python3 python3-pip sshpass",
 
      # Installation d'Ansible via pip3
      "pip3 install --upgrade pip",
      "pip3 install --user ansible",
     
      "python3 --version",
      "pip3 --version",
      "~/.local/bin/ansible --version"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_dev_test_linux_virtual_machine.vmapp.fqdn
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  depends_on = [azurerm_dev_test_linux_virtual_machine.vmapp]
}

# Upload Ansible directory
resource "null_resource" "upload_ansible" {
  provisioner "file" {
    source      = "./ansible"
    destination = "/home/${var.username_app}/ansible"

    connection {
      type        = "ssh"
      host        = azurerm_dev_test_linux_virtual_machine.vmapp.fqdn
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  depends_on = [null_resource.setup_ansible]
}
# Upload SSH key (private)
resource "null_resource" "upload_ssh_key" {
  provisioner "file" {
    source      = "./ssh/id_ed25519"
    destination = "/home/${var.username_app}/.ssh/id_ed25519"

    connection {
      type        = "ssh"
      host        = azurerm_dev_test_linux_virtual_machine.vmapp.fqdn
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 /home/${var.username_app}/.ssh",
      "chmod 600 /home/${var.username_app}/.ssh/id_ed25519"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_dev_test_linux_virtual_machine.vmapp.fqdn
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  depends_on = [azurerm_dev_test_linux_virtual_machine.vmapp, null_resource.upload_ansible]
}

# Convert the key to Unix format using dos2unix
resource "null_resource" "format_ssh_key" {
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update && sudo apt-get install -y dos2unix",
      "dos2unix /home/${var.username_app}/.ssh/id_ed25519"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_dev_test_linux_virtual_machine.vmapp.fqdn
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  depends_on = [null_resource.upload_ssh_key]
}

# Generate inventory (unchanged)
resource "null_resource" "generate_inventory" {
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/${var.username_app}/ansible/inventories",
      "cd /home/${var.username_app}/ansible/inventories",
      "echo 'all:' > hosts.yml",
      "echo '  hosts:' >> hosts.yml",
      "echo '    slave1:' >> hosts.yml",
      "echo '      ansible_host: ${azurerm_dev_test_linux_virtual_machine.vmapp.fqdn}' >> hosts.yml",
      "echo '      ansible_user: ${var.username_app}' >> hosts.yml",
      "echo '      ansible_ssh_private_key_file: /home/${var.username_app}/.ssh/id_ed25519' >> hosts.yml",
      "echo '      ansible_ssh_common_args: \"-o StrictHostKeyChecking=no\"' >> hosts.yml"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_dev_test_linux_virtual_machine.vmapp.fqdn
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  depends_on = [null_resource.upload_ansible, null_resource.format_ssh_key]
}

# Run Ansible playbook
resource "null_resource" "run_playbook" {
  provisioner "remote-exec" {
    inline = [
      "set -eux",
      "mkdir -p ~/.ssh && ssh-keyscan -H ${azurerm_dev_test_linux_virtual_machine.vmapp.fqdn} >> ~/.ssh/known_hosts",
      "~/.local/bin/ansible-playbook -i /home/${var.username_app}/ansible/inventories/hosts.yml /home/${var.username_app}/ansible/playbook.yml -vv"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_dev_test_linux_virtual_machine.vmapp.fqdn
      user        = var.username_app
      private_key = file("./ssh/id_ed25519")
    }
  }

  depends_on = [null_resource.generate_inventory]
}