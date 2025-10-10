locals {
  resource_group_name = "VZCORP-AGENTSASSEMBLE"
  location            = "westeurope"
  application_number  = "vzcorp-agentsassemble-001"
  environment         = "Prod"
  common_tags = {
    applicationNumber = local.application_number
    organization      = "vzcorp"
    project           = "agentsAssemble"
    environment       = local.environment
  }
  vnet_address_space = ["192.168.0.0/24"]
  subnet_config = {
    name             = "snet-private-endpoints"
    address_prefixes = ["192.168.0.0/24"]
  }
}

# Data source to get current Azure client configuration
data "azurerm_client_config" "current" {}

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
resource "azurerm_network_security_group" "private_endpoints_nsg" {
  name                = "${local.resource_group_name}-snet-private-endpoints-nsg"
  location            = module.workload_rg.resource.location
  resource_group_name = module.workload_rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "allow_https_outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Virtual Network with subnet
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.1.0"

  resource_group_name = module.workload_rg.name
  vnet_location       = module.workload_rg.resource.location
  name                = "${local.resource_group_name}-vnet"
  address_space       = local.vnet_address_space[0]

  subnet_names    = [local.subnet_config.name]
  subnet_prefixes = local.subnet_config.address_prefixes

  nsg_ids = {
    (local.subnet_config.name) = azurerm_network_security_group.private_endpoints_nsg.id
  }

  tags = local.common_tags

  enable_telemetry = true
}

# Storage Account
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.1.0"

  resource_group_name = module.workload_rg.name
  location            = module.workload_rg.resource.location
  name                = lower(replace("${local.resource_group_name}sa", "-", ""))

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  access_tier              = "Hot"

  # Disable public access for security
  public_network_access_enabled = false
  shared_access_key_enabled     = true

  tags = local.common_tags

  enable_telemetry = true
}

# Private DNS Zone for blob storage
module "private_dns_zone_blob" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.1.0"

  resource_group_name = module.workload_rg.name
  domain_name         = "privatelink.blob.core.windows.net"

  virtual_network_links = {
    vnet-link = {
      vnetlinkname = "${local.resource_group_name}-vnet-link"
      vnetid       = module.vnet.vnet_id
    }
  }

  dns_zone_tags = local.common_tags

  enable_telemetry = true
}

# Private Endpoint for Storage Account Blob
module "storage_private_endpoint" {
  source  = "Azure/avm-res-network-privateendpoint/azurerm"
  version = "0.1.0"

  resource_group_name = module.workload_rg.name
  location            = module.workload_rg.resource.location
  name                = "${local.resource_group_name}-storage-blob-pe"

  subnet_resource_id = module.vnet.subnet_ids[local.subnet_config.name]

  network_interface_name = "${local.resource_group_name}-storage-blob-nic"

  private_connection_resource_id  = module.storage_account.id
  private_service_connection_name = "${local.resource_group_name}-storage-blob-psc"
  subresource_names               = ["blob"]

  private_dns_zone_group_name   = "blob-dns-zone-group"
  private_dns_zone_resource_ids = [module.private_dns_zone_blob.private_dnz_zone_output.id]

  tags = local.common_tags

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
  description = "The resource ID of the virtual network"
}

output "storage_account_name" {
  value       = module.storage_account.name
  description = "The name of the storage account"
}

output "storage_account_id" {
  value       = module.storage_account.id
  description = "The resource ID of the storage account"
}

output "private_endpoint_id" {
  value       = module.storage_private_endpoint.resource_id
  description = "The resource ID of the storage private endpoint"
}
