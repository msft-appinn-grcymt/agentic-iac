locals {
  resource_group_name = "VZCORP-agentsAssemble"
  location            = "westeurope"
  application_number  = "agentsAssemble"
  environment         = "Prod"
  common_tags = {
    applicationNumber = local.application_number
    organization      = "vzcorp"
    project           = "agentsAssemble"
    environment       = local.environment
  }

  # Network configuration from spec: VNet 192.168.0.0/24, one subnet for private endpoints /24
  vnet_address_space = ["192.168.0.0/24"]
  subnet_private_endpoints = {
    name             = "snet-private-endpoints"
    address_prefixes = ["192.168.0.0/26"]
  }
}

# Resource Group for the workload
module "workload_rg" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.2.1"

  name     = local.resource_group_name
  location = local.location
  tags     = local.common_tags
}

# Network Security Group for private endpoints subnet
module "nsg_private_endpoints" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.0"

  resource_group_name = module.workload_rg.name
  location            = local.location
  name                = "${local.resource_group_name}-snet-private-endpoints-nsg"
  tags                = local.common_tags

  security_rules = {
    allow_https_outbound = {
      name                       = "AllowHTTPSOutbound"
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
}

# Virtual Network with subnet for private endpoints
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.15.0"

  parent_id        = module.workload_rg.resource_id
  location         = local.location
  name             = "${local.resource_group_name}-vnet"
  address_space    = local.vnet_address_space
  enable_telemetry = true
  tags             = local.common_tags

  subnets = {
    private_endpoints = {
      name             = local.subnet_private_endpoints.name
      address_prefixes = local.subnet_private_endpoints.address_prefixes
      network_security_group = {
        id = module.nsg_private_endpoints.resource_id
      }
    }
  }
}

# Private DNS Zone for Storage Blob
module "private_dns_zone_blob" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.4.2"

  domain_name = "privatelink.blob.core.windows.net"
  parent_id   = module.workload_rg.resource_id
  tags        = local.common_tags

  virtual_network_links = {
    vnet_link = {
      name   = "${local.resource_group_name}-vnet-link"
      vnetid = module.vnet.resource_id
    }
  }
}

# Storage Account with private endpoint
# Based on spec: Block Blob Storage, General Purpose V2, ZRS Redundancy, Hot Access Tier
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.6.4"

  resource_group_name      = module.workload_rg.name
  location                 = local.location
  name                     = lower(replace("st${local.resource_group_name}", "-", ""))
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  access_tier              = "Hot"
  enable_telemetry         = true
  tags                     = local.common_tags

  # Disable public network access
  public_network_access_enabled = false

  # Enable blob service
  blob_properties = {
    versioning_enabled = false
  }

  # Configure private endpoint for blob
  private_endpoints = {
    blob = {
      subnet_resource_id            = module.vnet.subnets["private_endpoints"].resource_id
      private_dns_zone_resource_ids = [module.private_dns_zone_blob.resource_id]
      subresource_name              = "blob"
      name                          = "${local.resource_group_name}-st-pe-blob"
    }
  }
}

# Outputs
output "resource_group_name" {
  description = "The name of the resource group"
  value       = module.workload_rg.name
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = module.vnet.name
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = module.storage_account.name
}

output "storage_account_id" {
  description = "The ID of the storage account"
  value       = module.storage_account.resource_id
}
