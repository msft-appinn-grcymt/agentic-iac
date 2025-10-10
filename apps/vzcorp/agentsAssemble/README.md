# vzcorp/agentsAssemble Infrastructure

This directory contains Terraform configuration for the vzcorp/agentsAssemble workload, implementing a secure-by-default Azure landing zone using Azure Verified Modules (AVM).

## Overview

Based on specification: `specs/vzcorp/agentsAssemble/agentsAssemble.xlsx`

- **Organization**: vzcorp
- **Project**: agentsAssemble
- **Resource Group**: VZCORP-AGENTSASSEMBLE
- **Location**: West Europe
- **Environment**: Production

## Infrastructure Components

### Networking
- **Virtual Network**: 192.168.0.0/24
- **Subnet**: snet-private-endpoints (192.168.0.0/24)
  - Purpose: Private endpoints
  - Network Security Group: VZCORP-AGENTSASSEMBLE-snet-private-endpoints-nsg
  - Security rules:
    - Allow VNet-to-VNet traffic (inbound/outbound)
    - Allow Azure Load Balancer inbound
    - Allow Storage service outbound (TCP/443)
    - Deny all other traffic

### Storage
- **Storage Account**: vzcorpagentsassemblest
  - Type: StorageV2 (General Purpose V2)
  - Performance: Standard
  - Replication: Zone-Redundant Storage (ZRS)
  - Access Tier: Hot
  - Public Access: Disabled
  - Features:
    - Private endpoint for blob storage
    - Network rules: Deny all public access
    - Azure Services bypass enabled

### Private DNS
- **DNS Zone**: privatelink.blob.core.windows.net
  - Virtual network link to VZCORP-AGENTSASSEMBLE-vnet
  - Automatic DNS resolution for private endpoints

### Private Endpoint
- **Blob Private Endpoint**: Connects storage account to private subnet
  - Service: blob
  - DNS integration via private DNS zone group
  - Network interface: vzcorpagentsassemblest-blob-pe-nic

## Module Versions

All modules use pinned Azure Verified Module (AVM) versions:

| Module | Version | Purpose |
|--------|---------|---------|
| Azure/avm-res-resources-resourcegroup/azurerm | 0.1.0 | Resource group management |
| Azure/avm-res-network-networksecuritygroup/azurerm | 0.2.0 | Network security groups |
| Azure/avm-res-network-virtualnetwork/azurerm | 0.4.0 | Virtual networking |
| Azure/avm-res-network-privatednszone/azurerm | 0.1.2 | Private DNS zones |
| Azure/avm-res-storage-storageaccount/azurerm | 0.2.7 | Storage accounts |
| Azure/avm-res-network-privateendpoint/azurerm | 0.2.0 | Private endpoints |

## Requirements

- Terraform >= 1.9.2
- Azure Provider >= 3.111.0
- Azure subscription with appropriate permissions

## Usage

### Initialize

```bash
terraform init
```

### Validate

```bash
terraform validate
```

### Plan

```bash
terraform plan
```

### Apply

```bash
terraform apply
```

## Outputs

The configuration exports the following outputs:

- `resource_group_name` - Name of the created resource group
- `resource_group_id` - Azure resource ID of the resource group
- `vnet_name` - Name of the virtual network
- `vnet_id` - Azure resource ID of the virtual network
- `nsg_subnets` - List of subnets with their associated NSGs
- `storage_account_name` - Name of the storage account
- `storage_account_id` - Azure resource ID of the storage account
- `private_endpoint_id` - Azure resource ID of the private endpoint

## Security Features

- ✅ Private-first networking (no public endpoints)
- ✅ Network security groups with least-privilege rules
- ✅ Private DNS integration for secure name resolution
- ✅ Zone-redundant storage for high availability
- ✅ Comprehensive resource tagging for governance
- ✅ All traffic flows through private network paths

## Tags

All resources are tagged with:
- `applicationNumber`: N/A (no request number provided in spec)
- `organization`: vzcorp
- `project`: agentsAssemble
- `environment`: Prod

## Deployment Notes

1. This configuration uses Azure Verified Modules exclusively
2. No backend configuration is included - configure as needed for your environment
3. The storage account name is derived from the resource group name (lowercase, no hyphens)
4. Private endpoint DNS integration requires proper DNS resolution in the VNet
5. All public access is disabled by default for security compliance

## Compliance

This infrastructure follows:
- Azure Well-Architected Framework principles
- Private-first networking requirements
- Secure-by-default configuration patterns
- Azure Verified Module best practices
