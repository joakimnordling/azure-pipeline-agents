locals {
  windows_pipeline_agent_name  = var.windows_pipeline_agent_name != "" ? "${lower(var.windows_pipeline_agent_name)}-${terraform.workspace}" : local.windows_vm_name
  windows_vm_name              = "${var.windows_vm_name_prefix}-${terraform.workspace}-${var.suffix}"
  windows_vm_computer_name     = "${var.windows_vm_name_prefix}${substr(terraform.workspace,0,3)}${var.suffix}w"
}

resource azurerm_public_ip windows_pip {
  name                         = "${local.windows_vm_name}${count.index+1}-pip"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  allocation_method            = "Static"
  sku                          = "Standard"

  tags                         = var.tags
  count                        = var.windows_agent_count
}

resource azurerm_network_interface windows_nic {
  name                         = "${local.windows_vm_name}${count.index+1}-nic"
  location                     = var.location
  resource_group_name          = var.resource_group_name

  ip_configuration {
    name                       = "ipconfig"
    subnet_id                  = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id       = azurerm_public_ip.windows_pip[count.index].id
  }
  enable_accelerated_networking = var.vm_accelerated_networking

  tags                         = var.tags
  count                        = var.windows_agent_count
}

resource azurerm_network_interface_security_group_association windows_nic_nsg {
  network_interface_id         = azurerm_network_interface.windows_nic[count.index].id
  network_security_group_id    = azurerm_network_security_group.nsg.id

  count                        = var.windows_agent_count
}

resource azurerm_storage_blob install_agent {
  name                         = "install_agent.ps1"
  storage_account_name         = local.scripts_storage_name
  storage_container_name       = local.scripts_container_name

  type                         = "Block"
  source                       = "${path.root}/../scripts/agent/install_agent.ps1"

  count                        = var.windows_agent_count > 0 ? 1 : 0
}

resource azurerm_windows_virtual_machine windows_agent {
  name                         = "${local.windows_vm_name}${count.index+1}"
  computer_name                = "${local.windows_vm_computer_name}${count.index+1}"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  network_interface_ids        = [azurerm_network_interface.windows_nic[count.index].id]
  size                         = var.windows_vm_size
  admin_username               = var.user_name
  admin_password               = var.user_password

  os_disk {
    name                       = "${local.windows_vm_name}${count.index+1}-osdisk"
    caching                    = "ReadWrite"
    storage_account_type       = var.windows_storage_type
  }

  source_image_reference {
    publisher                  = var.windows_os_publisher
    offer                      = var.windows_os_offer
    sku                        = var.windows_os_sku
    version                    = "latest"
  }

  # Required for AAD Login
  identity {
    type                       = "SystemAssigned"
  }
  
  tags                         = var.tags
  count                        = var.windows_agent_count
}
resource azurerm_virtual_machine_extension windows_log_analytics {
  name                         = "MMAExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent[count.index].id
  publisher                    = "Microsoft.EnterpriseCloud.Monitoring"
  type                         = "MicrosoftMonitoringAgent"
  type_handler_version         = "1.0"
  auto_upgrade_minor_version   = true

  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
    "azureResourceId"          = azurerm_windows_virtual_machine.windows_agent[count.index].id
    "stopOnMultipleConnections"= "true"
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  tags                         = var.tags

  count                        = var.linux_agent_count
}
resource azurerm_virtual_machine_extension windows_dependency_monitor {
  name                         = "DAExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent[count.index].id
  publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                         = "DependencyAgentWindows"
  type_handler_version         = "9.5"
  auto_upgrade_minor_version   = true

  settings                     = jsonencode({
    "workspaceId"              = data.azurerm_log_analytics_workspace.monitor.workspace_id
  })
  protected_settings           = jsonencode({
    "workspaceKey"             = data.azurerm_log_analytics_workspace.monitor.primary_shared_key
  })

  tags                         = var.tags

  count                        = var.linux_agent_count
}
resource azurerm_virtual_machine_extension windows_watcher {
  name                         = "AzureNetworkWatcherExtension"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent[count.index].id
  publisher                    = "Microsoft.Azure.NetworkWatcher"
  type                         = "NetworkWatcherAgentWindows"
  type_handler_version         = "1.4"
  auto_upgrade_minor_version   = true

  tags                         = var.tags

  count                        = var.linux_agent_count
}

resource azurerm_virtual_machine_extension windows_pipeline_agent {
  name                         = "PipelineAgentCustomScript"
  virtual_machine_id           = azurerm_windows_virtual_machine.windows_agent[count.index].id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"
  auto_upgrade_minor_version   = true
  settings                     = <<EOF
    {
      "fileUris": [
                                 "${azurerm_storage_blob.install_agent.0.url}"
      ]
    }
  EOF

  protected_settings           = <<EOF
    { 
      "commandToExecute"       : "powershell.exe -ExecutionPolicy Unrestricted -Command \"./install_agent.ps1 -AgentName ${local.windows_pipeline_agent_name}${count.index+1} -AgentPool ${var.windows_pipeline_agent_pool} -Organization ${var.devops_org} -PAT ${var.devops_pat}\""
    } 
  EOF

  # Start VM, so we can update/destroy the extension
  provisioner local-exec {
    command                    = "az vm start --ids ${self.virtual_machine_id}"
  }
  provisioner local-exec {
    when                       = destroy
    command                    = "az vm start --ids ${self.virtual_machine_id}"
  }

  count                        = var.windows_agent_count
  depends_on                   = [
    azurerm_virtual_machine_extension.windows_log_analytics,
    azurerm_virtual_machine_extension.windows_dependency_monitor,
    azurerm_virtual_machine_extension.windows_watcher,
  ]
}