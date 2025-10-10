locals {
  resource_group_name = "VZCORP-AGENTSASSEMBLE"
  location            = "westeurope"
  application_number  = "N/A"
  environment         = "Prod"
  common_tags = {
    applicationNumber = local.application_number
    organization      = "vzcorp"
    project           = "agentsAssemble"
    environment       = local.environment
  }

  # Network configuration based on specification
  vnet_address_space = ["192.168.0.0/24"]

  subnets = [
    {
      name             = "snet-private-endpoints"
      usage            = "PrivateEndpoints"
      address_prefixes = ["192.168.0.0/24"]
      network_security_group = {
        name = "snet-private-endpoints-nsg"
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
          },
          {
            name                       = "AllowAzureLoadBalancerInbound"
            priority                   = 110
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "AzureLoadBalancer"
            destination_address_prefix = "*"
          },
          {
            name                       = "DenyAllInbound"
            priority                   = 4096
            direction                  = "Inbound"
            access                     = "Deny"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "*"
            destination_address_prefix = "*"
          },
          {
            name                       = "AllowVnetOutbound"
            priority                   = 100
            direction                  = "Outbound"
            access                     = "Allow"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "VirtualNetwork"
            destination_address_prefix = "VirtualNetwork"
          },
          {
            name                       = "AllowStorageOutbound"
            priority                   = 110
            direction                  = "Outbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_port_range          = "*"
            destination_port_range     = "443"
            source_address_prefix      = "*"
            destination_address_prefix = "Storage"
          },
          {
            name                       = "DenyAllOutbound"
            priority                   = 4096
            direction                  = "Outbound"
            access                     = "Deny"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "*"
            destination_address_prefix = "*"
          }
        ]
      }
    }
  ]
}

# Resource Group
module "workload_rg" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.1.0"

  name     = local.resource_group_name
  location = local.location
  tags     = local.common_tags
}

# Network Security Groups for Subnets
module "subnet_nsg" {
  for_each = { for subnet in local.subnets : subnet.name => subnet if can(subnet.network_security_group) }

  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "0.2.0"

  resource_group_name = module.workload_rg.name
  name                = "${local.resource_group_name}-${each.key}-nsg"
  location            = local.location

  security_rules = {
    for rule in each.value.network_security_group.rules : rule.name => {
      name                       = rule.name
      priority                   = rule.priority
      direction                  = rule.direction
      access                     = rule.access
      protocol                   = rule.protocol
      source_port_range          = rule.source_port_range
      destination_port_range     = rule.destination_port_range
      source_address_prefix      = rule.source_address_prefix
      destination_address_prefix = rule.destination_address_prefix
    }
  }

  tags = local.common_tags
}

# Virtual Network
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.4.0"

  resource_group_name = module.workload_rg.name
  location            = local.location
  name                = "${local.resource_group_name}-vnet"
  address_space       = local.vnet_address_space

  subnets = {
    for subnet in local.subnets : subnet.name => {
      name             = subnet.name
      address_prefixes = subnet.address_prefixes
      network_security_group = {
        id = module.subnet_nsg[subnet.name].resource_id
      }
    }
  }

  tags = local.common_tags
}

# Private DNS Zone for Storage Blob
module "private_dns_zone_blob" {
  source  = "Azure/avm-res-network-privatednszone/azurerm"
  version = "0.1.2"

  resource_group_name = module.workload_rg.name
  domain_name         = "privatelink.blob.core.windows.net"
  tags                = local.common_tags

  virtual_network_links = {
    vnet_link = {
      vnetlinkname     = "${local.resource_group_name}-vnet-link"
      vnetid           = module.vnet.resource_id
      autoregistration = false
    }
  }
}

# Storage Account
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.2.7"

  resource_group_name = module.workload_rg.name
  location            = local.location
  name                = lower(replace("${local.resource_group_name}st", "-", ""))

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  access_tier              = "Hot"

  # Disable public access
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true

  # Enable blob storage features
  blob_properties = {
    versioning_enabled       = false
    change_feed_enabled      = false
    last_access_time_enabled = false
  }

  network_rules = {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  tags = local.common_tags
}

# Private Endpoint for Storage Blob
module "storage_private_endpoint" {
  source  = "Azure/avm-res-network-privateendpoint/azurerm"
  version = "0.2.0"

  name                           = "${module.storage_account.name}-blob-pe"
  resource_group_name            = module.workload_rg.name
  location                       = local.location
  subnet_resource_id             = module.vnet.subnets["snet-private-endpoints"].resource_id
  network_interface_name         = "${module.storage_account.name}-blob-pe-nic"
  private_connection_resource_id = module.storage_account.resource_id
  subresource_names              = ["blob"]

  private_dns_zone_resource_ids = [
    module.private_dns_zone_blob.resource_id
  ]
  private_dns_zone_group_name = "default"

  tags = local.common_tags
}
