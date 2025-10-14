# vzcorp/agentsAssemble Infrastructure

## Overview
This Terraform configuration provisions a secure Azure infrastructure for the vzcorp agentsAssemble project using Azure Verified Modules (AVM).

## Specification Source
Based on the specification file: `specs/vzcorp/agentsAssemble/agentsAssemble.xlsx`

## Infrastructure Components

### Resource Group
- **Name**: VZCORP-AGENTSASSEMBLE
- **Location**: West Europe
- **Tags**: Organization, Project, Application Number, Environment

### Networking
- **Virtual Network**: 192.168.0.0/24
  - Address space configured for private endpoint connectivity
- **Subnet**: snet-privateendpoints
  - CIDR: 192.168.0.0/24
  - Service Endpoints: Microsoft.Storage
  - Associated with NSG for traffic control

### Network Security
- **Network Security Group**: vzcorp-agents-pe-nsg
  - Outbound rule allowing HTTPS (443) to Azure Storage service

### Storage
- **Storage Account**: vzcorpagentsassemblesa
  - Type: General Purpose V2 (StorageV2)
  - Replication: Zone-Redundant Storage (ZRS)
  - Access Tier: Hot
  - **Security**: Public network access disabled
  - **Private Connectivity**: Private endpoint for blob storage

### Private DNS
- **Private DNS Zone**: privatelink.blob.core.windows.net
  - Linked to the virtual network for private endpoint name resolution
  - Enables seamless private connectivity to storage blob service

## Azure Verified Modules (AVM) Used

All modules are pinned to version 0.1.0 (latest available as of deployment):

| Module | Source | Purpose |
|--------|--------|---------|
| workload_rg | Azure/avm-res-resources-resourcegroup/azurerm | Resource group creation |
| vnet | Azure/avm-res-network-virtualnetwork/azurerm | Virtual network and subnets |
| private_dns_zone_blob | Azure/avm-res-network-privatednszone/azurerm | Private DNS for blob storage |
| storage_account | Azure/avm-res-storage-storageaccount/azurerm | Storage account with private endpoint |

## Security Features

1. **No Public Access**: Storage account has public network access disabled
2. **Private Endpoints**: All storage access goes through private endpoints within the VNet
3. **Private DNS**: Automatic DNS resolution for private endpoint connectivity
4. **Network Security Group**: Traffic filtering at the subnet level
5. **Service Endpoints**: Optimized routing for Azure Storage traffic

## Deployment

### Prerequisites
- Terraform >= 1.7.0
- Azure CLI authenticated
- Appropriate Azure subscription permissions

### Commands
```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply
```

### CI/CD Deployment
This workload can be deployed using the GitHub Actions workflow:
```bash
# Trigger via workflow_dispatch in GitHub Actions
# Organization: vzcorp
# Project: agentsAssemble
```

## Outputs

| Output | Description |
|--------|-------------|
| resource_group_name | Name of the created resource group |
| vnet_name | Name of the virtual network |
| vnet_id | Azure resource ID of the virtual network |
| storage_account_name | Name of the storage account |
| storage_account_id | Azure resource ID of the storage account |

## Compliance
- Follows Azure Verified Modules specifications
- Private-first networking architecture
- All resources tagged for governance and cost tracking
