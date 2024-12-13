output "lab_name" {
  description = "Dev test lab name"
  value       = var.devtestlab_name
}

output "resource_group_name" {
  description = "Resource group name"
  value       = var.resource_group_name
}


output "vm_name" {
  value = azurerm_dev_test_linux_virtual_machine.vmapp.name
}

output "vm_fqdn" {
  value = azurerm_dev_test_linux_virtual_machine.vmapp.fqdn
}

output "playbook_result" {
  value = chomp(file("./logs/playbook_output.txt"))
  description = "The result of the Ansible playbook execution."
}
