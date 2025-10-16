locals {
  organization        = "vzcorp"
  project             = "agentsAssemble"
  resource_group_name = "${upper(local.organization)}-${upper(local.project)}"
  location            = "westeurope"
  application_number  = "AG001"
  environment         = "Prod"

  common_tags = {
    applicationNumber = local.application_number
    organization      = local.organization
    project           = local.project
    environment       = local.environment
  }

  # VNet and subnet configuration from spec: 192.168.0.0/24 with one subnet for private endpoints
  vnet_address_space = ["192.168.0.0/24"]
  subnets = {
    private_endpoints = {
      name             = "snet-private-endpoints"
      address_prefixes = ["192.168.0.0/25"]
      delegation       = null
      service_endpoints = [
        "Microsoft.Storage"
      ]
    }
  }
}

# Random suffix for globally unique storage account name
resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
module "workload_rg" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.2.1"

  name             = local.resource_group_name
  location         = local.location
  tags             = local.common_tags
  enable_telemetry = true
}

# Network Security Group for private endpoints subnet
module "private_endpoints_nsg" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.0"

  resource_group_name = module.workload_rg.name
  name                = "${module.workload_rg.name}-snet-pe-nsg"
  location            = local.location
  tags                = local.common_tags
  enable_telemetry    = true

  security_rules = {
    AllowStorageOutbound = {
      name                       = "AllowStorageOutbound"
      priority                   = 100
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "Storage"
    }
  }
}

# Virtual Network with subnet
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.15.0"

  parent_id        = module.workload_rg.resource_id
  location         = local.location
  name             = "${module.workload_rg.name}-vnet"
  address_space    = local.vnet_address_space
  tags             = local.common_tags
  enable_telemetry = true

  subnets = {
    for key, subnet in local.subnets : key => {
      name              = subnet.name
      address_prefixes  = subnet.address_prefixes
      delegation        = subnet.delegation
      service_endpoints = subnet.service_endpoints
      network_security_group = {
        id = module.private_endpoints_nsg.resource_id
      }
    }
  }
}

# Storage Account (Block Blob, General Purpose V2, ZRS redundancy, Hot tier)
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.6.4"

  resource_group_name = module.workload_rg.name
  location            = local.location
  name                = "${substr(lower("st${local.organization}${local.project}"), 0, 18)}${random_string.storage_suffix.result}"

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  access_tier              = "Hot"

  # Disable public network access - private endpoints only
  public_network_access_enabled   = false
  shared_access_key_enabled       = true
  allow_nested_items_to_be_public = false

  # Enable blob versioning and change feed
  blob_properties = {
    versioning_enabled  = true
    change_feed_enabled = true
  }

  network_rules = {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = []
    virtual_network_subnet_ids = [
      module.vnet.subnets["private_endpoints"].resource_id
    ]
  }

  tags             = local.common_tags
  enable_telemetry = true
}

# Private Endpoint for Storage Account (Blob)
module "storage_blob_private_endpoint" {
  source  = "Azure/avm-res-network-privateendpoint/azurerm"
  version = "0.2.0"

  resource_group_name = module.workload_rg.name
  location            = local.location
  name                = "${module.storage_account.name}-blob-pe"

  network_interface_name         = "${module.storage_account.name}-blob-pe-nic"
  subnet_resource_id             = module.vnet.subnets["private_endpoints"].resource_id
  private_connection_resource_id = module.storage_account.resource_id

  subresource_names = ["blob"]

  tags             = local.common_tags
  enable_telemetry = true
}

# Outputs
output "resource_group_name" {
  description = "The name of the resource group"
  value       = module.workload_rg.name
}

output "resource_group_location" {
  description = "The location of the resource group"
  value       = local.location
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = module.vnet.name
}

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = module.vnet.resource_id
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = module.storage_account.name
}

output "storage_account_id" {
  description = "The ID of the storage account"
  value       = module.storage_account.resource_id
}

output "storage_blob_private_endpoint_id" {
  description = "The ID of the blob private endpoint"
  value       = module.storage_blob_private_endpoint.resource_id
}
