locals {
  resource_group_name = "vzcorp-agentsAssemble"
  location            = "westeurope"
  application_number  = "N/A" # Not specified in Excel
  environment         = "Prod"

  common_tags = {
    applicationNumber = local.application_number
    organization      = "vzcorp"
    project           = "agentsAssemble"
    environment       = local.environment
  }

  # Network configuration from Excel Sheet 2
  vnet_address_space = ["192.168.0.0/24"]

  subnets = [
    {
      name             = "snet-privateendpoints"
      address_prefixes = ["192.168.0.0/24"]
      network_security_group = {
        name = "snet-privateendpoints-nsg"
        rules = [
          {
            name                       = "AllowVnetInbound"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "VirtualNetwork"
            destination_address_prefix = "VirtualNetwork"
          }
        ]
      }
    }
  ]

  # Storage account configuration from Excel Sheet 1
  storage_account_name = lower(replace("${local.resource_group_name}st", "/[^a-z0-9]/", ""))
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

# Network Security Groups (must be created before subnets)
module "nsg" {
  for_each = { for subnet in local.subnets : subnet.name => subnet if can(subnet.network_security_group) }

  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.5.0"

  resource_group_name = module.workload_rg.name
  name                = each.value.network_security_group.name
  location            = local.location
  security_rules      = each.value.network_security_group.rules
  tags                = local.common_tags
  enable_telemetry    = true
}

# Virtual Network with subnets
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.15.0"

  parent_id     = module.workload_rg.resource_id
  location      = local.location
  name          = "${local.resource_group_name}-vnet"
  address_space = local.vnet_address_space

  subnets = {
    for subnet in local.subnets : subnet.name => {
      name             = subnet.name
      address_prefixes = subnet.address_prefixes
      network_security_group = {
        id = can(subnet.network_security_group) ? module.nsg[subnet.name].resource_id : null
      }
    }
  }

  tags             = local.common_tags
  enable_telemetry = true

  depends_on = [module.nsg]
}

# Private DNS Zone for Storage Account Blob
module "private_dns_blob" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.4.2"

  parent_id        = module.workload_rg.resource_id
  domain_name      = "privatelink.blob.core.windows.net"
  tags             = local.common_tags
  enable_telemetry = true

  virtual_network_links = {
    vnet_link = {
      vnetlinkname = "${local.resource_group_name}-vnet-link"
      vnetid       = module.vnet.resource_id
    }
  }
}

# Storage Account
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.6.4"

  resource_group_name = module.workload_rg.name
  location            = local.location
  name                = substr(local.storage_account_name, 0, 24) # Max 24 characters for storage account name

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  access_tier              = "Hot"

  # Security settings - private access only
  public_network_access_enabled   = false
  shared_access_key_enabled       = true
  allow_nested_items_to_be_public = false

  # Hierarchical namespace disabled (Flat Namespace as per spec)
  is_hns_enabled = false

  # SFTP disabled as per spec
  sftp_enabled = false

  tags             = local.common_tags
  enable_telemetry = true

  # Private endpoint configuration
  private_endpoints = {
    blob_pe = {
      name                          = "${local.resource_group_name}-storage-blob-pe"
      subnet_resource_id            = module.vnet.subnets["snet-privateendpoints"].resource_id
      subresource_name              = "blob"
      private_dns_zone_resource_ids = [module.private_dns_blob.resource_id]
    }
  }

  depends_on = [module.vnet, module.private_dns_blob]
}
