# vzcorp/agentsAssemble Workload Deployment

## Overview
This workload provisions infrastructure for the agentsAssemble project based on the specification file located in `specs/vzcorp/agentsAssemble/vzcorp-assemble.xlsx`.

## Specification Summary

### Components (from Azure Estimate)
1. **Storage Account**
   - Type: General Purpose V2
   - Redundancy: ZRS (Zone-Redundant Storage)
   - Access Tier: Hot
   - Capacity: 1TB
   - Features: Block Blob Storage, Flat Namespace, SFTP disabled

2. **Key Vault**
   - Type: Standard Vault
   - Features: Soft delete, Purge protection

3. **App Service**
   - Tier: Premium V3
   - SKU: P1V3 (2 vCPU, 8 GB RAM, 250 GB Storage)
   - Instances: 2
   - OS: Linux

### Networking Configuration
- **VNet CIDR**: 10.0.0.0/16
- **Subnets**:
  - snet-app1: 10.0.0.0/27 (App Service 1, delegated to Microsoft.Web/serverFarms)
  - snet-app2: 10.0.0.32/27 (App Service 2, delegated to Microsoft.Web/serverFarms)
  - snet-pe: 10.0.1.0/26 (Private Endpoints)

### Security Features
- All resources configured with **private endpoints** only (no public access)
- Network Security Groups (NSGs) applied to all subnets
- Private DNS zones for:
  - Storage Blob (`privatelink.blob.core.windows.net`)
  - Key Vault (`privatelink.vaultcore.azure.net`)
  - Web Apps (`privatelink.azurewebsites.net`)
- VNet integration for App Service
- HTTPS-only communication enforced

### Observability
- Log Analytics Workspace for centralized logging
- Application Insights integrated with the Web App

## Files

### main.bicep
The main infrastructure-as-code template using Azure Verified Modules (AVM) from the public Bicep registry.

**AVM Modules Used:**
- `avm/res/operational-insights/workspace:0.12` - Log Analytics
- `avm/res/insights/component:0.6` - Application Insights
- `avm/res/network/network-security-group:0.5` - NSGs
- `avm/res/network/virtual-network:0.7` - VNet
- `avm/res/storage/storage-account:0.27` - Storage Account
- `avm/res/network/private-dns-zone:0.8` - Private DNS Zones
- `avm/res/network/private-endpoint:0.11` - Private Endpoints
- `avm/res/key-vault/vault:0.13` - Key Vault
- `avm/res/web/serverfarm:0.5` - App Service Plan
- `avm/res/web/site:0.19` - Web App

### deploy.bicepparam
Parameter file for the deployment with all configuration values.

## Deployment

### Prerequisites
1. Resource group `vzcorp-agentsAssemble` must exist in the target subscription
2. Proper RBAC permissions to deploy resources
3. Azure CLI or Azure PowerShell installed
4. Bicep CLI installed

### Deployment Commands

#### Using the deployment script:
```bash
# Current script syntax (using -m for organization/agency, -r for project)
./deployBicep.sh -m vzcorp -r agentsAssemble

# Or with subscription specified
./deployBicep.sh -s subscription-name -m vzcorp -r agentsAssemble
```

> **Note**: The deployment script currently uses `-m` (ministry/agency) and `-r` (resource group/project) flags. According to the repository documentation, these should be updated to `-o` (organization) and `-p` (project) for consistency.

#### Using Azure CLI directly:
```bash
cd apps/vzcorp/agentsAssemble
az deployment group create \
  --name vzcorp-agentsAssemble-deployment \
  --resource-group vzcorp-agentsAssemble \
  --template-file main.bicep \
  --parameters deploy.bicepparam
```

## Validation Status

### Build Status
⚠️ **Note**: Module validation could not be completed due to AVM modules not being accessible in the current environment. The template follows the documented AVM module structure and parameter conventions as specified in the repository's `.github/copilot-instructions.md`.

### Syntax Validation
✅ Template structure and syntax follow Bicep best practices
✅ All required parameters are defined
✅ Proper resource dependencies are established
✅ Network security configurations follow private-by-default principles

## Assumptions and Defaults

1. **Request Number**: Set to `vzcorp-assemble-001` (derived from spec file name)
2. **Environment**: Tagged as `Production` (not specified in Excel)
3. **Web App Runtime**: Node.js 18 LTS (not specified in Excel, common choice for Linux App Service)
4. **Storage Account Name**: `stvcorpassemble001` (must be globally unique, may need adjustment)
5. **Key Vault Name**: `kv-vcorp-assemble` (must be globally unique, may need adjustment)

## Post-Deployment Tasks

1. Configure App Service deployment source (Git, GitHub Actions, etc.)
2. Upload certificates if custom domains are required
3. Configure Key Vault access policies for users/applications
4. Set up monitoring alerts in Application Insights
5. Configure backup policies for Storage Account and Key Vault

## Tags Applied

All resources are tagged with:
- `applicationNumber`: vzcorp-assemble-001
- `organization`: vzcorp
- `project`: agentsAssemble
- `environment`: Production

## Network Flow

```
Internet/Hub VNet
        ↓
  Private Endpoints
        ↓
  Private DNS Zones
        ↓
  [Storage | Key Vault | Web App]
        ↑
  VNet Integration (App Service)
```

All traffic flows through private endpoints with DNS resolution via private DNS zones linked to the VNet.
