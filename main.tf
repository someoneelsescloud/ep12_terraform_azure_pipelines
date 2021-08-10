########### Locals ###########
locals {
  name_1     = var.assetname
  locationid = var.location
  rg_name    = "${var.assetname}-${var.environment}-${local.locationid}"
  res_name   = "${var.assetname}-${var.environment}"
  sa_name    = "${local.name_1}sa${random_integer.number.result}"
}

resource "random_integer" "number" {
  min = 100
  max = 999
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

########### Management 1  ###########
resource "azurerm_resource_group" "resourcegroup_1" {
  name     = "${local.rg_name}-rg-1"
  location = local.locationid

  tags = {
    environment = var.environment
  }

}

resource "azurerm_virtual_network" "virtualnetwork_1" {
  name                = "${local.res_name}-vnet-1"
  location            = azurerm_resource_group.resourcegroup_1.location
  resource_group_name = azurerm_resource_group.resourcegroup_1.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = var.environment
  }

}

resource "azurerm_subnet" "subnet_1" {
  name                 = "${local.res_name}-subnet-1"
  virtual_network_name = azurerm_virtual_network.virtualnetwork_1.name
  resource_group_name  = azurerm_resource_group.resourcegroup_1.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [
    azurerm_virtual_network.virtualnetwork_1
  ]
}

########### Log Analytics Workspace ###########
resource "azurerm_log_analytics_workspace" "law_1" {
  name                = "${local.res_name}-logs-1"
  location            = azurerm_resource_group.resourcegroup_1.location
  resource_group_name = azurerm_resource_group.resourcegroup_1.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = var.environment
  }

}

########### VMInsights Solution ###########
resource "azurerm_log_analytics_solution" "vminsights" {
  solution_name         = "VMInsights"
  location              = azurerm_resource_group.resourcegroup_1.location
  resource_group_name   = azurerm_resource_group.resourcegroup_1.name
  workspace_resource_id = azurerm_log_analytics_workspace.law_1.id
  workspace_name        = azurerm_log_analytics_workspace.law_1.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }

}

########### Data sources for Log Analytics Workspace ###########
resource "azurerm_log_analytics_datasource_windows_event" "app_1" {
  name                = "windows-app-logs"
  resource_group_name = azurerm_resource_group.resourcegroup_1.name
  workspace_name      = azurerm_log_analytics_workspace.law_1.name
  event_log_name      = "Application"
  event_types         = ["error", "information", "warning"]

  depends_on = [
    azurerm_log_analytics_workspace.law_1
  ]
}

resource "azurerm_log_analytics_datasource_windows_event" "sys_1" {
  name                = "windows-sys-logs"
  resource_group_name = azurerm_resource_group.resourcegroup_1.name
  workspace_name      = azurerm_log_analytics_workspace.law_1.name
  event_log_name      = "System"
  event_types         = ["error", "information", "warning"]

  depends_on = [
    azurerm_log_analytics_workspace.law_1
  ]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "cpu_1" {
  name                = "perf-cpu-1"
  resource_group_name = azurerm_resource_group.resourcegroup_1.name
  workspace_name      = azurerm_log_analytics_workspace.law_1.name
  object_name         = "CPU"
  instance_name       = "*"
  counter_name        = "CPU"
  interval_seconds    = 10

  depends_on = [
    azurerm_log_analytics_workspace.law_1
  ]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "cpu_2" {
  name                = "perf-cpu-2"
  resource_group_name = azurerm_resource_group.resourcegroup_1.name
  workspace_name      = azurerm_log_analytics_workspace.law_1.name
  object_name         = "Processor"
  instance_name       = "_Total"
  counter_name        = "% Processor Time"
  interval_seconds    = 10

  depends_on = [
    azurerm_log_analytics_workspace.law_1
  ]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "mem_1" {
  name                = "perf-memory-1"
  resource_group_name = azurerm_resource_group.resourcegroup_1.name
  workspace_name      = azurerm_log_analytics_workspace.law_1.name
  object_name         = "Memory"
  instance_name       = "*"
  counter_name        = "Available MBytes"
  interval_seconds    = 10

  depends_on = [
    azurerm_log_analytics_workspace.law_1
  ]
}

resource "azurerm_log_analytics_datasource_windows_performance_counter" "mem_2" {
  name                = "perf-memory-2"
  resource_group_name = azurerm_resource_group.resourcegroup_1.name
  workspace_name      = azurerm_log_analytics_workspace.law_1.name
  object_name         = "Memory"
  instance_name       = "*"
  counter_name        = "% Committed Bytes in Use"
  interval_seconds    = 10
}

########### KeyVault ###########

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "keyvault_1" {
  name                        = "${local.res_name}-kv-1"
  location                    = azurerm_resource_group.resourcegroup_1.location
  resource_group_name         = azurerm_resource_group.resourcegroup_1.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled    = false

  enabled_for_deployment          = true
  enabled_for_template_deployment = true

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
      "Backup",
      "Delete",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set"
    ]

    storage_permissions = [
      "Get",
    ]
  }

  tags = {
    environment = var.environment
  }

}

resource "azurerm_key_vault_secret" "localadmin" {
  name         = "localadmin"
  value        = random_password.password.result
  key_vault_id = azurerm_key_vault.keyvault_1.id

  depends_on = [
    azurerm_key_vault.keyvault_1
  ]
}

resource "azurerm_key_vault_secret" "workspacekey" {
  name         = "workspacekey"
  value        = azurerm_log_analytics_workspace.law_1.primary_shared_key
  key_vault_id = azurerm_key_vault.keyvault_1.id

  depends_on = [
    azurerm_key_vault.keyvault_1,
    azurerm_log_analytics_workspace.law_1
  ]

}

########### Storage Account ###########
resource "azurerm_storage_account" "storage_1" {
  name                     = local.sa_name
  resource_group_name      = azurerm_resource_group.resourcegroup_1.name
  location                 = azurerm_resource_group.resourcegroup_1.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = var.environment
  }

}

########### Virtual Machine #1 ###########
resource "azurerm_network_interface" "virtualmachine_1" {
  name                = "${local.res_name}-nic-1"
  location            = azurerm_resource_group.resourcegroup_1.location
  resource_group_name = azurerm_resource_group.resourcegroup_1.name

  ip_configuration {
    name                          = "${local.res_name}-1"
    subnet_id                     = azurerm_subnet.subnet_1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.virtualmachine_1.id
  }

  tags = {
    environment = var.environment
  }

  depends_on = [
    azurerm_subnet.subnet_1
  ]

}

resource "azurerm_public_ip" "virtualmachine_1" {
  name                    = "${local.res_name}-public-vm-nic-1"
  location                = azurerm_resource_group.resourcegroup_1.location
  resource_group_name     = azurerm_resource_group.resourcegroup_1.name
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 10
}

resource "azurerm_windows_virtual_machine" "virtualmachine_1" {
  name                  = "${local.res_name}-vm-1"
  location              = azurerm_resource_group.resourcegroup_1.location
  resource_group_name   = azurerm_resource_group.resourcegroup_1.name
  network_interface_ids = [azurerm_network_interface.virtualmachine_1.id]
  size                  = "Standard_DS1_v2"
  admin_username        = "localadmin"
  admin_password        = random_password.password.result

  provision_vm_agent = true
  timezone           = "AUS Eastern Standard Time"

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = {
    environment = var.environment
  }

  depends_on = [
    azurerm_subnet.subnet_1
  ]


}

resource "azurerm_virtual_machine_extension" "vm1_monitoring" {
  virtual_machine_id         = azurerm_windows_virtual_machine.virtualmachine_1.id
  name                       = "MicrosoftMonitoringAgent"
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = <<-SETTINGS
    {
      "workspaceId": "${azurerm_log_analytics_workspace.law_1.workspace_id}"
    }
  SETTINGS

  protected_settings = <<-PROTECTEDSETTINGS
    {
    "workspaceKey": "${azurerm_log_analytics_workspace.law_1.primary_shared_key}"
    }
  PROTECTEDSETTINGS

  depends_on = [
    azurerm_windows_virtual_machine.virtualmachine_1
  ]
}

resource "azurerm_virtual_machine_extension" "vm1_depenancy" {
  virtual_machine_id         = azurerm_windows_virtual_machine.virtualmachine_1.id
  name                       = "Microsoft.Azure.Monitoring.DependencyAgent"
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.5"
  auto_upgrade_minor_version = true

  depends_on = [
    azurerm_windows_virtual_machine.virtualmachine_1
  ]
}
