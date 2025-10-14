locals {
  resource_group_name = "VZCORP-AGENTSASSEMBLE"
  location            = "westeurope"
  application_number  = "VZCORP-AA-001"
  environment         = "Prod"

  common_tags = {
    applicationNumber = local.application_number
    organization      = "vzcorp"
    project           = "agentsAssemble"
    environment       = local.environment
  }

  vnet_address_space = "192.168.0.0/24"
  subnet_name        = "snet-privateendpoints"
  subnet_prefix      = "192.168.0.0/24"
}

# Resource Group
module "workload_rg" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.1.0"

  name     = local.resource_group_name
  location = local.location
  tags     = local.common_tags

  enable_telemetry = true
}

# Network Security Group for private endpoints subnet
resource "azurerm_network_security_group" "privateendpoints_nsg" {
  name                = "vzcorp-agents-pe-nsg"
  location            = module.workload_rg.resource.location
  resource_group_name = module.workload_rg.name

  security_rule {
    name                       = "AllowStorageOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Storage"
  }

  tags = local.common_tags
}

# Virtual Network
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.1.0"

  resource_group_name = module.workload_rg.name
  name                = "${local.resource_group_name}-vnet"
  vnet_location       = local.location
  address_space       = local.vnet_address_space

  subnet_names    = [local.subnet_name]
  subnet_prefixes = [local.subnet_prefix]

  nsg_ids = {
    (local.subnet_name) = azurerm_network_security_group.privateendpoints_nsg.id
  }

  subnet_service_endpoints = {
    (local.subnet_name) = ["Microsoft.Storage"]
  }

  tags             = local.common_tags
  enable_telemetry = true
}

# Private DNS Zone for Storage Blob
module "private_dns_zone_blob" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.1.0"

  resource_group_name = module.workload_rg.name
  domain_name         = "privatelink.blob.core.windows.net"

  virtual_network_links = {
    vnet_link = {
      vnetlinkname = "${local.resource_group_name}-vnet-link"
      vnetid       = module.vnet.vnet_id
    }
  }

  dns_zone_tags    = local.common_tags
  enable_telemetry = true
}

# Storage Account with Private Endpoint
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.1.0"

  resource_group_name = module.workload_rg.name
  location            = local.location
  name                = lower(replace("${local.resource_group_name}sa", "-", ""))

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  access_tier              = "Hot"

  # Disable public access
  public_network_access_enabled = false

  # Private endpoint configuration
  private_endpoints = {
    blob = {
      subnet_resource_id            = module.vnet.subnet_ids[local.subnet_name]
      subresource_name              = ["blob"]
      private_dns_zone_resource_ids = [module.private_dns_zone_blob.private_dnz_zone_output.id]
      tags                          = local.common_tags
    }
  }

  tags             = local.common_tags
  enable_telemetry = true
}

# Outputs
output "resource_group_name" {
  value       = module.workload_rg.name
  description = "The name of the resource group"
}

output "vnet_name" {
  value       = module.vnet.vnet_name
  description = "The name of the virtual network"
}

output "vnet_id" {
  value       = module.vnet.vnet_id
  description = "The ID of the virtual network"
}

output "storage_account_name" {
  value       = module.storage_account.name
  description = "The name of the storage account"
}

output "storage_account_id" {
  value       = module.storage_account.id
  description = "The ID of the storage account"
}
