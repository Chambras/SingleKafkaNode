resource "azurerm_storage_account" "genericSA" {
  name                     = var.storageAccountName
  resource_group_name      = azurerm_resource_group.genericRG.name
  location                 = azurerm_resource_group.genericRG.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "GRS"

  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.sourceIPs
    virtual_network_subnet_ids = [
      azurerm_subnet.subnets["headnodes"].id,
      azurerm_subnet.dbSubnets["publicDB"].id,
      azurerm_subnet.dbSubnets["privateDB"].id,
    ]
  }

  tags = var.tags
}

resource "azurerm_storage_container" "container" {
  name                  = "data"
  storage_account_id    = azurerm_storage_account.genericSA.id
  container_access_type = "private"
}

resource "azurerm_storage_account" "ADLS" {
  name                     = "${var.storageAccountName}adsl"
  resource_group_name      = azurerm_resource_group.genericRG.name
  location                 = azurerm_resource_group.genericRG.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  https_traffic_only_enabled = true
  min_tls_version            = "TLS1_2"

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.sourceIPs
    virtual_network_subnet_ids = [
      azurerm_subnet.subnets["headnodes"].id,
      azurerm_subnet.dbSubnets["publicDB"].id,
      azurerm_subnet.dbSubnets["privateDB"].id,
    ]
  }

  tags = var.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "ADLSFileSystemTFMS" {
  name               = "tfms"
  storage_account_id = azurerm_storage_account.ADLS.id
}
