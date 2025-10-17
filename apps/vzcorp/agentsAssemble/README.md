# vzcorp - agentsAssemble Infrastructure

This directory contains Terraform configuration for the `vzcorp-agentsAssemble` workload deployment based on Azure Verified Modules (AVM).

## Specifications

Based on Excel specification file: `specs/vzcorp/agentsAssemble/agentsAssemble.xlsx`

### Components (Sheet 1)
- **Storage Account**: General Purpose V2, ZRS redundancy, Hot access tier
  - Type: Block Blob Storage
  - Namespace: Flat (hierarchical namespace disabled)
  - SFTP: Disabled
  - Public access: Disabled (private endpoints only)

### Network (Sheet 2)
- **Virtual Network**: 192.168.0.0/24
- **Subnet**: snet-privateendpoints (192.168.0.0/24)
  - Purpose: Private endpoints for services
  - NSG: Attached with basic VNet traffic rules

## Resources Created

1. **Resource Group**: `vzcorp-agentsAssemble`
   - Location: West Europe
   - Tags: organization, project, environment, applicationNumber

2. **Network Security Group**: `snet-privateendpoints-nsg`
   - Rules: Allow VNet inbound traffic

3. **Virtual Network**: `vzcorp-agentsAssemble-vnet`
   - Address space: 192.168.0.0/24
   - Subnet: snet-privateendpoints with NSG attached

4. **Private DNS Zone**: `privatelink.blob.core.windows.net`
   - VNet link configured for name resolution

5. **Storage Account**: `vzcorpagentsassemblest`
   - SKU: Standard_ZRS
   - Kind: StorageV2
   - Access tier: Hot
   - Private endpoint for blob storage
   - Public network access: Disabled

## AVM Module Versions

- Resource Group: v0.2.1
- Network Security Group: v0.5.0
- Virtual Network: v0.15.0
- Private DNS Zone: v0.4.2
- Storage Account: v0.6.4

## Deployment

### Prerequisites
- Terraform >= 1.9.5
- Azure CLI authentication configured
- Appropriate Azure subscription permissions

### Steps

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Destroy resources (if needed)
terraform destroy
```

## Security Features

- **Private-first networking**: All services use private endpoints
- **No public ingress**: Public network access disabled on storage account
- **NSG protection**: Network security groups applied to subnets
- **Private DNS integration**: DNS zones configured for private endpoint resolution

## Notes

- Application number not specified in the Excel specification (set to "N/A")
- Environment defaulted to "Prod"
- Storage account name sanitized to meet Azure naming requirements (lowercase, alphanumeric only, max 24 chars)
