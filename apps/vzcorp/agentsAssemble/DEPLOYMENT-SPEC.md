# Deployment Specification Translation

## Excel Specification → Terraform Mapping

### Sheet 1: Components

| Excel Field | Value | Terraform Implementation |
|-------------|-------|-------------------------|
| Service Category | Storage | `module "storage_account"` |
| Service Type | Storage Accounts | AVM storage account module v0.6.4 |
| Region | West Europe | `location = "westeurope"` |
| Storage Type | General Purpose V2 | `account_kind = "StorageV2"` |
| Redundancy | ZRS | `account_replication_type = "ZRS"` |
| Access Tier | Hot | `access_tier = "Hot"` |
| Namespace | Flat Namespace | `is_hns_enabled = false` |
| SFTP | Disabled | `sftp_enabled = false` |
| Public Access | N/A | `public_network_access_enabled = false` (per security policy) |

### Sheet 2: Network

| Excel Field | Value | Terraform Implementation |
|-------------|-------|-------------------------|
| VNet CIDR | 192.168.0.0/24 | `address_space = ["192.168.0.0/24"]` |
| Subnet | one subnet for private endpoints /24 | `snet-privateendpoints` with CIDR 192.168.0.0/24 |

### Derived Resources (Security Requirements)

The following resources were added to meet the repository's security and networking best practices:

1. **Network Security Group**: `snet-privateendpoints-nsg`
   - Applied to the private endpoints subnet
   - Rules: Allow VNet inbound traffic

2. **Private DNS Zone**: `privatelink.blob.core.windows.net`
   - Required for private endpoint name resolution
   - Linked to the virtual network

3. **Private Endpoint**: `vzcorp-agentsAssemble-storage-blob-pe`
   - Connects storage account blob service to the private subnet
   - Integrated with private DNS zone

### Resource Naming Convention

All resources follow the naming pattern: `{organization}-{project}-{resource-type}`

- Resource Group: `vzcorp-agentsAssemble`
- Virtual Network: `vzcorp-agentsAssemble-vnet`
- Subnet: `snet-privateendpoints`
- NSG: `snet-privateendpoints-nsg`
- Storage Account: `vzcorpagentsassemblest` (sanitized for Azure requirements)
- Private Endpoint: `vzcorp-agentsAssemble-storage-blob-pe`

### Tags Applied

All resources are tagged with:
- `applicationNumber`: N/A (not specified in Excel)
- `organization`: vzcorp
- `project`: agentsAssemble
- `environment`: Prod

### Module Versions (Retrieved from Terraform Registry)

| Module | Source | Version | Registry URL |
|--------|--------|---------|--------------|
| Resource Group | Azure/avm-res-resources-resourcegroup/azurerm | 0.2.1 | https://registry.terraform.io/modules/Azure/avm-res-resources-resourcegroup/azurerm/0.2.1 |
| Network Security Group | Azure/avm-res-network-networksecuritygroup/azurerm | 0.5.0 | https://registry.terraform.io/modules/Azure/avm-res-network-networksecuritygroup/azurerm/0.5.0 |
| Virtual Network | Azure/avm-res-network-virtualnetwork/azurerm | 0.15.0 | https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm/0.15.0 |
| Private DNS Zone | Azure/avm-res-network-privatednszone/azurerm | 0.4.2 | https://registry.terraform.io/modules/Azure/avm-res-network-privatednszone/azurerm/0.4.2 |
| Storage Account | Azure/avm-res-storage-storageaccount/azurerm | 0.6.4 | https://registry.terraform.io/modules/Azure/avm-res-storage-storageaccount/azurerm/0.6.4 |

All versions were queried from the Terraform Registry API on 2025-10-17 and represent the latest available stable releases.

### Security Compliance Checklist

✅ **Private-first networking**: Storage account uses private endpoint only  
✅ **No public ingress**: `public_network_access_enabled = false`  
✅ **Subnet hygiene**: Non-overlapping CIDR (192.168.0.0/24), NSG attached  
✅ **Dependency ordering**: Resources created in correct sequence via `depends_on`  
✅ **Idempotency**: Terraform state management ensures safe re-runs  
✅ **Minimal configuration**: Only essential parameters specified, relying on Azure defaults  

### Assumptions and Defaults

1. **Application Number**: Not specified in Excel, defaulted to "N/A"
2. **Environment**: Defaulted to "Prod" (not specified in Excel)
3. **Subnet Usage**: Entire /24 allocated to private endpoints subnet
4. **Storage Account Tier**: Standard tier (derived from ZRS redundancy requirement)
5. **Private Endpoint**: Created for blob subresource only (can be extended for other services)

### Manual Steps Required

None - the Terraform configuration is fully automated and can be deployed using standard `terraform init/plan/apply` workflow.
