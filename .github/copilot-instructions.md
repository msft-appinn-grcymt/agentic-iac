# GSIS Agentic IaC - Copilot Agent Instructions

## Repository Overview
This repository contains Infrastructure as Code (IaC) modules written in Bicep for deploying Azure resources following organizational best practices including naming conventions and security requirements.

## Repository Structure
```
/
├── azure.deploy.bicep          # Entry point - references main.bicep
├── main.bicep                  # Main orchestration file with module invocations
├── deployBicep.sh              # Deployment shell script
├── apps/                       # Project-specific parameter files
│   └── {authority}/            # e.g., MIN6969
│       └── {resourceGroup}/    # e.g., RG6969
│           └── deploy.bicepparam  # Bicep parameter file
├── specs/                      # Excel specifications for incoming requests
│   └── {authority}/            # e.g., MIN6969
│       └── {resourceGroup}/    # e.g., RG6969
│           └── *.xlsx          # Single source of truth for requested resources; sheet 1 lists components to deploy, sheet 2 captures network details and address ranges and the respective request number to be used
└── modules/                    # Reusable Bicep modules (DO NOT MODIFY)
    ├── Backup/                 # Recovery vault
    ├── Compute/                # VMs, App Services, Static Web Apps
    ├── Containers/             # AKS
    ├── Databases/              # SQL, MySQL, PostgreSQL, CosmosDB
    ├── Helpers/                # Naming conventions module
    ├── Monitoring/             # Log Analytics, App Insights
    ├── Networking/             # VNet, Subnets, NSG, Private Endpoints, Gateways
    ├── Security/               # Key Vault
    └── Storage/                # Storage Accounts
```

## Key Principles
1. **DO NOT modify Bicep code** in `azure.deploy.bicep`, `main.bicep`, or any files in `modules/`
2. **Only create/modify** `.bicepparam` files under `apps/{authority}/{resourceGroup}/`
3. **All changes** are parameter-driven - modules support extensive parameterization
4. **Network deployment always occurs** - other resources are optional via flags

## Deployment Workflow
GitHub Actions workflow (`.github/workflows/deploy.yaml`) triggered manually with:
- **authority**: Maps to folder under `apps/` (e.g., MIN6969)
- **resourceGroup**: Maps to subfolder (e.g., RG6969)
- Executes: `bash deployBicep.sh -m {authority} -r {resourceGroup}`
- Parameter file location: `apps/{authority}/{resourceGroup}/deploy.bicepparam`
- Specification file location: `specs/{authority}/{resourceGroup}/*.xlsx`

### Resource Discovery Pre-check
- Use the Azure MCP tooling to query the subscription for existing resources prior to authoring parameters and any potential conflicts with the to-be deployed resources.In addition, the resource group (in format authority-resourceGroup, e.g., MIN200-RG240) must exist  before the deployment.If it doesn't then don't proceed with the deployment and report the issue.Check if the resource group or any other existing resources match the deployment requirements as well as if they are deployed on another region than the one specified in the parameters for the resources to be created.
- Look for matches in the target resource group named `{authority}-{resourceGroup}` (e.g., MIN200-RG240).
- Document any pre-existing resources that satisfy or conflict with the Excel requirements before proceeding with changes.

## Parameter File Structure

### Required Parameters (Every Deployment)
```bicep
using '../../../azure.deploy.bicep'

var requestNumber = '9999'
param intRequestNumber = requestNumber
param agency = 'MIN6969'              // Authority/Ministry name
param project = 'RG6969'              // Resource Group ID
param location = 'West Europe'        // Azure region
param tags = { applicationNumber: requestNumber }
param vnetAddressPrefix = ['192.168.0.0/16']
```

### Subnet Configuration (Always Required)
```bicep
param subnets = [
  { addressPrefix: '192.168.0.0/27', usage: 'VM' }
  { addressPrefix: '192.168.1.0/27', usage: 'VM/PrivateEndpoint' }
  { addressPrefix: '192.168.2.0/27', usage: 'AppService' }
  { addressPrefix: '192.168.3.0/28', usage: 'AppGateway' }
  { addressPrefix: '192.168.4.0/27', usage: 'mySQL' }
  { addressPrefix: '192.168.5.0/27', usage: 'Postgres' }
  { addressPrefix: '192.168.6.0/27', usage: 'VpnGateway' }
  { addressPrefix: '192.168.7.0/27', usage: 'AKS' }
]
// Valid usage values: VM, VM/PrivateEndpoint, AppService, mySQL, Postgres, AppGateway, VpnGateway, AKS
```

## Resource Modules & Parameters

### Compute Resources
**App Service**: `param appServiceCount = 2` (0 to disable), `param appServiceSkuName = 'P1v3'`, `param appServiceRuntime = 'linux*DOCKER|...'` (see allowed values in azure.deploy.bicep)

**Virtual Machines** (Array of Batches):
```bicep
param vmBatches = [
  {
    vmBatchName: 'A', vmCount: 3, vmsize: 'Standard_D4s_v4', subnetIndex: 1,
    vmOSType: 'Linux', vmOSpublisher: 'Canonical', vmOSOffer: '0001-com-ubuntu-server-jammy',
    vmOSSku: '22_04-lts-gen2', vmOSDiskType: 'StandardSSD_LRS', vmOSDiskSizeGB: 256, vmOSDiskDeleteOption: 'Delete'
  }
]
param vmAdminUsername = 'azureuser'
param vmAdminPassword = readEnvironmentVariable('IAC_VM_PWD','')
```

### Database Resources
**SQL Server**: `param sqlServerCount = 1`, `param sqlDbCount = 1`, `param sqlTier = 'Standard'`, `param sqlSkuName = 'S3'`, `param sqlServerAdmin = 'localadmin'`, `param sqlServerPwd = readEnvironmentVariable('IAC_SQL_PWD','')`

**MySQL** (Array of Instances):
```bicep
param mySqlBatches = [
  { name: 'mysql01', skuName: 'Standard_D2ads_v5', skuTier: 'GeneralPurpose', storageSizeGB: 64, subnetIndex: 4 }
]
param mySqlAdmin = 'mysqladmin'
param mySqlAdminPassword = readEnvironmentVariable('IAC_MYSQL_PWD','')
```

**PostgreSQL** (Array of Instances):
```bicep
param postgreSqlBatches = [
  { name: 'postgres01', skuName: 'Standard_D2s_v3', skuTier: 'GeneralPurpose', storageSizeGB: 128, subnetIndex: 5 }
]
param postgresAdmin = 'postgresadmin'
param postgresAdminPassword = readEnvironmentVariable('IAC_PG_PWD','')
```

**CosmosDB**: `param createCosmosDb = true` (boolean flag)

### Networking Resources
**Application Gateway**: `param createAppGateway = true`, `param appGWSkuTier = 'WAF_v2'`, `param appGwMaxCapacity = 5`
**VPN Gateway**: `param createVpnGw = true`
**NAT Gateway**: `param createNatGw = true`
**Load Balancer**: `param createLoadBalancer = true`, `param loadBalancerPublic = false`, `param loadBalancerSubnetIndex = 0`
**Bastion**: `param createBastion = true`, `param bastionVnetAddressPrefix = ['192.168.0.0/16']`
**DDoS Protection**: `param enableDdosProtection = true`

### Security & Storage
**Key Vault**: `param keyVaultCount = 2` (creates 2 Key Vaults, 0 to disable)
**Storage Account**: `param storageAccountCount = 1`, `param storageBlobPrivateEndpoint = true`, `param storageFilePrivateEndpoint = true`, `param storageTablePrivateEndpoint = false`, `param storageQueuePrivateEndpoint = false`

### Monitoring
**Log Analytics**: `param createLogAnalytics = true`
**Application Insights**: `param createAppInsights = true`

### Containers
**AKS** (Array of Clusters):
```bicep
param AKSClusterBatches = [
  {
    name: 'aks01', tier: 'Standard', subnetIndex: 7, systemPoolNodeCount: 3,
    systemPoolNodeSize: 'standard_d4s_v5', applicationPoolNodeCount: 3,
    applicationPoolNodeSize: 'standard_d4s_v5', azRedundant: true
  }
]
```

## Common Azure SKUs Reference
- **App Service**: P1v3, P2v3, P3v3, S1, S2, S3, B1, B2, B3
- **SQL Database**: Basic, S0-S12 (Standard), P1-P15 (Premium), GP_Gen5_2/4/8 (General Purpose), BC_Gen5_2/4/8 (Business Critical)
- **VMs**: Standard_B2s, Standard_D2s_v3, Standard_D4s_v4, Standard_E2as_v4, Standard_E4as_v4
- **MySQL/PostgreSQL**: Standard_B1ms, Standard_B2s, Standard_D2ads_v5, Standard_D4ads_v5

## Creating Parameter Files from Azure Pricing Calculator Excel
When provided an Azure Pricing Calculator xlsx:
1. Create folder structure: `apps/{authority}/{resourceGroup}/`
2. Create `deploy.bicepparam` with required parameters (agency, project, location, vnetAddressPrefix, subnets)
3. Map Excel resources to parameters:
   - VM rows → `vmBatches` array (group by SKU/OS)
   - SQL rows → `sqlServerCount`, `sqlDbCount`, `sqlSkuName`, `sqlTier`
   - App Service rows → `appServiceCount`, `appServiceSkuName`, `appServiceRuntime`
   - Storage rows → `storageAccountCount` + private endpoint flags
   - Key Vault rows → `keyVaultCount`
   - AKS rows → `AKSClusterBatches` array
   - MySQL/PostgreSQL rows → `mySqlBatches`/`postgreSqlBatches` arrays
4. Set count to 0 or empty array `[]` for unused resources
5. Define subnets with appropriate CIDR ranges and usage tags for all resources
6. Set boolean flags (`createAppGateway`, `createLogAnalytics`, etc.) based on Excel presence

## Limitations to Report
If requirements cannot be met due to module constraints:
- Document the limitation clearly (e.g., "Module does not support zone redundancy configuration")
- State what is "baked in" to the module that prevents the requirement
- Suggest workarounds if available (e.g., "Parameter can be modified post-deployment via Azure Portal")
