@description('Internal request number')
param intRequestNumber string
@description('Name of the application')
param applicationName string
@description('Location of the resources')
param location string = resourceGroup().location
@description('Tags for the resources')
param tags object
@description('Enable DDOS protection flag')
param enableDdosProtection bool = false
@description('The existing DDOS protection plan to use for the VNet')
param ddosProtectionPlanName string = 'GSIS-DDoS'
@description('Address prefix for the VNet')
param vnetAddressPrefix array
@description('Subnets for the VNet')
param subnets array
// @description('Array of Private DNS Zones to be created for Private Endpoints')
// param privateDnsZonesToCreate array = []
@description('Create Log Analytics Workspace')
param createLogAnalytics bool = false
@description('Create Application Insights Workspace')
param createAppInsights bool = false
@description('Existing Log Analytics Workspace - Only in case deployLogAnalytics is false')
param existingLogAnalyticsWorkspaceId string?
@description('Number of App Services')
param appServiceCount int = 0
@description('OS and runtime of the app service')
@allowed([
  'linux*DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
  'windows*dotnet|v6.0'
  'windows*dotnet|v7.0'
  'windows*dotnet|v8.0'
  'linux*dotnetcore|6.0'
  'linux*dotnetcore|7.0'
  'linux*dotnetcore|8.0'
  'windows*java|1.8'
  'windows*java|11'
  'windows*java|17'
  'linux*java|8'
  'linux*java|11'
  'linux*java|17'
  'windows*node|~18'
  'windows*node|~20'
  'linux*node|18-lts'
  'linux*node|20-lts'
  'linux*php|8.2'
  'linux*python|3.8'
  'linux*python|3.9'
  'linux*python|3.10'
  'linux*python|3.11'
  'linux*python|3.12'
])
param appServiceRuntime string
@description('SKU name of the app service')
param appServiceSkuName string
@description('Number of Key Vaults')
param keyVaultCount int = 0
@description('Number of Storage Accounts')
param storageAccountCount int = 0
@description('Enable Private Endpoint for Blob Storage')
param storageBlobPrivateEndpoint bool = false
@description('Enable Private Endpoint for File Shares')
param storageFilePrivateEndpoint bool = false
@description('Enable Private Endpoint for Table')
param storageTablePrivateEndpoint bool = false
@description('Enable Private Endpoint for Storage Queues')
param storageQueuePrivateEndpoint bool = false
@description('Create Application Gateway')
param createAppGateway bool = false
@description('SKU of the Application Gateway')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param appGWSkuTier string = 'Standard_v2'
@description('Maximum instances of the Application Gateway')
param appGwMaxCapacity int = 4
@description('Number of SQL Servers')
param sqlServerCount int = 0
@description('Number of SQL Databases - One per SQL Server')
param sqlDbCount int = 0
@description('SQL Database tier')
@allowed([
  'Basic'
  'Standard'
  'Premium'
  'GeneralPurpose'
  'BusinessCritical'
])
param sqlTier string = 'GeneralPurpose'
@description('SQL DB sku and cores')
param sqlSkuName string = 'GP_Gen5_2'
@description('Admin username for the SQL Server')
@secure()
param sqlServerAdmin string
@description('Admin password for the SQL Server')
@secure()
param sqlServerPwd string
@description('Number of Virtual Machine Batches to create')
param vmBatches array
@description('VM Admin user')
@secure()
param vmAdminUsername string
@description('VM Admin user password')
@secure()
param vmAdminPassword string
@description('The version of the platform image or marketplace image used to create the virtual machine')
param vmOSVersion string = 'latest'
@description('Number of MySQL Flexible servers instances to create')
param mySqlBatches array
@description('Admin username for the MySQL Server')
param mySqlAdmin string
@description('Admin password for the MySQL Server')
@secure()
param mySqlAdminPassword string
@description('Creation Bastion Hub for Subscription')
param createBastion bool = false
// Based on the needed resources decide on the required DNS Zones for private endpoints
@description('Bastion Vnet Address Prefix')
param bastionVnetAddressPrefix array = []
param ddosSubscription string = '3a0d7018-08bf-42cd-bb9b-85cf001a1c24'
param ddosResourceGroup string = 'GSIS-InfraNet-RG'
@description('PostgreSQL Flexible Servers to create')
param postgreSqlBatches array
@description('Admin username for the PostgreSQL Server')
@secure()
param postgresAdmin string
@description('Admin password for the PostgreSQL Server')
@secure()
param postgresAdminPassword string
@description('Create NAT Gateway')
param createNatGw bool = false
@description('Create VPN Gateway')
param createVpnGw bool = false
@description('Create Load Balancer')
param createLoadBalancer bool = false
@description('Is the Load Balancer public')
param loadBalancerPublic bool = false
@description('Index of Subnet for Internal Load Balancer Subnet Index')
param loadBalancerSubnetIndex int = 0
@description('Create Cosmos DB - NoSQL')
param createCosmosDb bool = false
//@description('Create AKS  - Azure Kubernetes Service')
//param createAKS bool = false
@description('Create AKS  - From Array')
param AKSClusterBatches array

var appServiceDnsZone = 'privatelink.azurewebsites.net'
var blobDnsZone = 'privatelink.blob${environment().suffixes.storage}'
var fileDnsZone = 'privatelink.file${environment().suffixes.storage}'
var tableDnsZone = 'privatelink.table${environment().suffixes.storage}'
var queueDnsZone = 'privatelink.queue${environment().suffixes.storage}'
var keyVaultDnsZone = 'privatelink.vaultcore.azure.net'
var sqlServerDnsZone = 'privatelink${environment().suffixes.sqlServerHostname}'
var mySqlFlexibleDnsZone = 'private.mysql.database.azure.com' //MySQL VNet integrated
var postgreSqlFlexibleDnsZone = 'private.postgres.database.azure.com' //PostgreSQL VNet integrated
var cosmosDbNoSqlDnsZone = 'privatelink.documents.azure.com'

// The privateDnsZonesInit array is initialized with the DNS Zones 
// that are needed for the private endpoints based on the resources to be created
var privateDnsZonesInit = [
  appServiceCount > 0 ? appServiceDnsZone : ''
  // If storage accounts with Blobs or VMs are deployed, then the blobDnsZone is added
  // needed for VMs because of the boot diagnostics storage account 
  storageAccountCount > 0 && storageBlobPrivateEndpoint ? blobDnsZone : ''
  storageAccountCount > 0 && storageFilePrivateEndpoint ? fileDnsZone : ''
  storageAccountCount > 0 && storageTablePrivateEndpoint ? tableDnsZone : ''
  storageAccountCount > 0 && storageQueuePrivateEndpoint ? queueDnsZone : ''
  keyVaultCount > 0 ? keyVaultDnsZone : ''
  sqlServerCount > 0 ? sqlServerDnsZone : ''
  length(mySqlBatches) > 0 ? mySqlFlexibleDnsZone : ''
  length(postgreSqlBatches) > 0 ? postgreSqlFlexibleDnsZone : ''
  createCosmosDb ? cosmosDbNoSqlDnsZone : ''
]

// Create table for filtering where only the needed zones have values
var privateDnsZonesToKeep = [for (item, i) in privateDnsZonesInit: item != '' ? item : []]

// Create the final array with only the zones to be created
var privateDnsZonesToCreate = intersection(privateDnsZonesToKeep, privateDnsZonesInit)

// // Get the DDOS protection plan ID

resource ddosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2021-05-01' existing = if (enableDdosProtection) {
  name: ddosProtectionPlanName
  scope: resourceGroup(ddosSubscription, ddosResourceGroup)
}

//Create the VNet
//Vnet CIDR & subnets are passed as parameters from the bicepparam file
module network 'modules/Networking/networkDeployment.module.bicep' = {
  name: '${applicationName}-Vnet'
  params: {
    vnetName: '${applicationName}-Vnet'
    vnetAddressPrefix: vnetAddressPrefix
    subnetConfigs: subnets
    ddosProtectionPlanId: enableDdosProtection ? ddosProtectionPlan.id : ''
    location: location
    tags: tags
  }
}

var minName = split(applicationName, '-')[0]

// If enabled create bastion resources on their specific resource group
// Bastion "Hub" Vnet
module bastionNetwork 'modules/Networking/networkDeployment.module.bicep' = if ((length(vmBatches) > 0) && (createBastion)) {
  name: '${minName}-Bastion-Vnet'
  scope: resourceGroup('${minName}-Bastion')
  params: {
    vnetName: '${minName}-Bastion-Vnet'
    vnetAddressPrefix: bastionVnetAddressPrefix
    subnetConfigs: [{
      addressPrefix: cidrSubnet(bastionVnetAddressPrefix[0], 24, 0)
      usage: 'Bastion'
    }]
    location: location
    tags: tags
  }
}

// Bastion Resource
module bastion 'modules/Networking/bastion.module.bicep' = if ((length(vmBatches) > 0) && (createBastion)) {
  name: '${minName}-Bastion'
  scope: resourceGroup('${minName}-Bastion')
  params: {
    name: '${minName}-Bastion'
    location: location
    subnetId: bastionNetwork.outputs.bastionSubnetId
    tags: tags
  }
}

// Add Vnet peering to MIN Bastion VNet
// Only if VMs are deployed
// Performs both to and from peering with Bastion Vnet
module peerToBastion 'modules/Networking/vnetPeering.module.bicep' = if (length(vmBatches) > 0) {
  name: '${applicationName}-Vnet-Peering-To-Bastion'
  params: {
    vnetName: network.outputs.vnetName
    peerVnetName: createBastion ? bastionNetwork.outputs.vnetName : '${minName}-Bastion-Vnet'
    peerVnetResourceGroup: '${minName}-Bastion'
  }
}

module peerFromBastion 'modules/Networking/vnetPeering.module.bicep' = if (length(vmBatches) > 0) {
  name: '${applicationName}-Vnet-Peering-From-Bastion'
  scope: resourceGroup('${minName}-Bastion')
  params: {
    vnetName: createBastion ? bastionNetwork.outputs.vnetName : '${minName}-Bastion-Vnet'
    peerVnetName: network.outputs.vnetName
    peerVnetResourceGroup: resourceGroup().name
  }
}

//Create a new log analytics workspace if createLogAnalytics is true
module law 'modules/Monitoring/logAnalytics.module.bicep' = if (createLogAnalytics) {
  name: '${applicationName}-LAW'
  params: {
    location: location
    name: '${applicationName}-LAW'
    tags: tags
  }
}

//Create Application Insights
//Use the newly created log analytics workspace or an existing one that is passed as input
module appInsights 'modules/Monitoring/appInsights.module.bicep' = if (createAppInsights) {
  name: '${applicationName}-AppIns'
  params: {
    location: location
    name: '${applicationName}-AppIns'
    logAnalyticsWorkspaceId: createLogAnalytics ? law.outputs.workspaceId : existingLogAnalyticsWorkspaceId
    tags: tags
  }
}

//Create all the required private DNS zones for the private endpoints
// The privateDnsZonesToCreate array is set based on the resources that are to be created
module privateDnsZones 'modules/Networking/privateDnsZone.module.bicep' = {
  name: 'privateDnsZones'
  params: {
    dnsZones: privateDnsZonesToCreate
    vnetIds: [ network.outputs.vnetId ]
    tags: tags
  }
}

// Create app service(s)
// By default Vnet Integrated and Private Endpoint enabled
// App is deployed on a subnet named 'snet-app' which is defined on the bicep param file
module appService 'modules/Compute/appservice.module.bicep' = [for i in range(0, appServiceCount): {
  name: '${applicationName}-WebApp0${i + 1}'
  params: {
    name: '${applicationName}-WebApp0${i + 1}'
    location: location
    runtimeSpec: appServiceRuntime
    skuName: appServiceSkuName
    subnetIdForIntegration: network.outputs.appServiceSubnetIds[i]
    privateDnsZoneId: first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == appServiceDnsZone)).id
    privateEndpointSubnet: network.outputs.privateEndpointSubnetId 
    tags: tags
  }
}]

// Create Key Vault(s)
// Private and on standard tier
module keyvault 'modules/Security/keyvault.module.bicep' = [for i in range(0, keyVaultCount): {
  name: '${applicationName}-KV0${i + 1}'
  params: {
    name: '${applicationName}-KV0${i + 1}'
    privateDnsZoneId: first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == keyVaultDnsZone)).id
    privateEndpointSubnet: network.outputs.privateEndpointSubnetId
    location: location
    tags: tags
  }
}]

// Create Storage Account(s)
// Public access disabled and with private endpoints for Blob and Fileshares
// Default to LRS and Hot access tier
module storageAccount 'modules/Storage/storageAccount.module.bicep' = [for i in range(0, storageAccountCount): {
  name: '${toLower(applicationName)}sa0${i + 1}'
  params: {
    location: location
    name: '${toLower(applicationName)}sa0${i + 1}'
    privateEndpointSubnet: network.outputs.privateEndpointSubnetId
    createPrivateEndpointBlob: storageBlobPrivateEndpoint
    privateDnsBlob: storageBlobPrivateEndpoint ? first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == blobDnsZone)).id : null
    createPrivateEndpointFile: storageFilePrivateEndpoint
    privateDnsFile: storageFilePrivateEndpoint ? first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == fileDnsZone)).id : null
    createPrivateEndpointTable: storageTablePrivateEndpoint
    privateDnsTable: storageTablePrivateEndpoint ? first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == tableDnsZone)).id : null
    createPrivateEndpointQueue: storageQueuePrivateEndpoint
    privateDnsQueue: storageQueuePrivateEndpoint ? first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == queueDnsZone)).id : null
    tags: tags
  }
}]

//Create an Application Gateway
//Default to Standard_v2 SKU
//Dummy http listener with backend pool with no targets
//Default min 1 and max 4 instances

module applicationGateway 'modules/Networking/applicationGateway.module.bicep' = if (createAppGateway) {
  name: '${applicationName}-AppGW'
  params: {
    dnsLabelPrefix: toLower(applicationName)
    // frontendWebAppFqdn: 
    name: '${applicationName}-AppGW'
    skuTier: appGWSkuTier
    autoscaleMaxCapacity: appGwMaxCapacity
    subnetId: network.outputs.appGatewaySubnetId
    location: location
    tags: tags
  }
}

//Create SQL Server(s)
//Default with disabled public access and with a private endpoint and TLS 1.2
module sqlServer 'modules/Databases/sqlServer.module.bicep' = [for i in range(0, sqlServerCount): {
  name: '${applicationName}-mssqlsrv0${i + 1}'
  params: {
    name: '${applicationName}-mssqlsrv0${i + 1}'
    administratorLogin: sqlServerAdmin
    administratorLoginPassword: sqlServerPwd
    privateDnsZoneId: first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == sqlServerDnsZone)).id
    privateEndpointSubnet: network.outputs.privateEndpointSubnetId
    location: location
    tags: tags
  }
}]

//Create a database in the SQL Server
//Defaults to GP_Gen5_2 SKU
//Defaults to 32G GB Storage
//Defaults to SQL_Latin1_General_CP1_CI_AS
//Defaults to 15 Days for backup retention
module sqlDatabase 'modules/Databases/sqlDb.module.bicep' = [for i in range(0, sqlDbCount): {
  name: '${applicationName}-MSSQL0${i + 1}'
  params: {
    sqlDBName: '${applicationName}-MSSQL0${i + 1}'
    sqlServerName: sqlServer[i].outputs.sqlServerName
    tier: sqlTier
    skuName: sqlSkuName
    location: location
    tags: tags
  }
}]

// Create Storage Account for Boot Diagnostics
// Public access disabled and with private endpoints for Blob 
// Default to LRS and Hot access tier
module bootDiagStorageAccount 'modules/Storage/storageAccount.module.bicep' = if (length(vmBatches) > 0) {
  name: '${toLower(applicationName)}sadiag'
  params: {
    location: location
    name: '${toLower(applicationName)}sadiag'
    privateEndpointSubnet: ''//network.outputs.privateEndpointSubnetId
    isVMDiagnostics: true
    publicNetworkAccess: 'Enabled'
    // privateDnsBlob: first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == blobDnsZone)).id
    kind: 'Storage'
    accessTier: 'Cool'
    tags: tags
  }
}

// Create Virtual Machine(s)
// Default OS is Linux VM with Ubuntu 22.04 LTS
// Default sku is Standard DS2 v2
// Default OS disk is Standard LRS 128GB with delete

module virtualMachineBatches 'modules/Compute/virtualMachineBatch.module.bicep' = [ for (vmBatch,i) in vmBatches: {
  name: '${applicationName}-VM-Batch-${i}'
  params: {
    vmBatchName: vmBatch.vmOSType=='Linux' ? '${applicationName}-${vmBatch.vmBatchName}' : length('${split(applicationName,'-')[0]}${split(applicationName,'-')[1]}${vmBatch.vmBatchName}') <= 11 ? '${split(applicationName,'-')[0]}${split(applicationName,'-')[1]}${vmBatch.vmBatchName}' : '${intRequestNumber}-${vmBatch.vmBatchName}' 
    vmBatchCount: vmBatch.vmCount
    location: location
    tags: tags
    vmSize: vmBatch.vmsize
    vmAdminUsername: vmAdminUsername
    vmAdminPassword: vmAdminPassword
    vmSubnetId: network.outputs.subnets[vmBatch.subnetIndex].id
    vmOSpublisher: vmBatch.vmOSpublisher
    vmOSOffer: vmBatch.vmOSOffer
    vmOSSku: vmBatch.vmOSSku
    vmOSVersion: vmOSVersion
    vmOSType: vmBatch.vmOSType
    vmOSDiskType: vmBatch.vmOSDiskType
    vmOSDiskSizeGB: vmBatch.vmOSDiskSizeGB
    vmOSDiskDeleteOption: vmBatch.vmOSDiskDeleteOption
    bootDiagStorageAccount: bootDiagStorageAccount.outputs.storageBlobUri
    recoveryServicesVault: recoveryServicesVault.outputs.name
  }
}]

// Create Recovery Services Vault if VMs are deployed 
// Standard tier with locally redundant storage and public access
// Default and Enhanced Policies for VMs modified to Daily at 1:30AM Athens time
module recoveryServicesVault 'modules/Backup/recoveryVault.module.bicep' = if (length(vmBatches) > 0) {
  name: '${applicationName}-BackupVault'
  params: {
    name: '${applicationName}-BackupVault'
    location: location
    tags: tags
  }
}

// Create MySQL Flexible Server(s)
// Defaults to VNet Integrated
// Default to 492 IOPS - 64GB Storage - General Purpose Standard D2ads_v5
// Default to version 8.0.21

module mySQLFlexibleServer 'modules/Databases/mySql.module.bicep' = [ for (mySQL,i) in mySqlBatches: {
  name: '${toLower(applicationName)}-mysql0${i + 1}'
  params: {
    name: '${toLower(applicationName)}-mysql0${i + 1}'
    administratorLogin: mySqlAdmin
    administratorLoginPassword: mySqlAdminPassword
    skuName: mySQL.mySqlSkuName
    skuTier: mySQL.mySqlTier
    storageSizeGB: mySQL.mySqlStorageSizeGB
    version: mySQL.mySqlVersion
    privateDnsZoneId: first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == mySqlFlexibleDnsZone)).id
    subnetId: network.outputs.mySQLSubnetIds[i]
    location: location
    tags: tags
  }
}]

/// PostgreSQL Flexible Server(s)

module postgreSQLFlexibleServer 'modules/Databases/postgress.module.bicep' = [ for (postgreSQL,i) in postgreSqlBatches: {
  name: '${toLower(applicationName)}-postgres0${i + 1}'
  params: {
    name: '${toLower(applicationName)}-postgres0${i + 1}'
    administratorLogin: postgresAdmin
    administratorLoginPassword: postgresAdminPassword
    skuName: postgreSQL.postgreSqlSkuName
    skuTier: postgreSQL.postgreSqlTier
    storageSizeGB: postgreSQL.postgreSqlStorageSizeGB
    version: postgreSQL.postgreSqlVersion
    postgresqlDnsZoneId: first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == postgreSqlFlexibleDnsZone)).id
    postgresqlSubnetId: network.outputs.postgreSQLSubnetIds[i]
    location: location
    tags: tags
  }

}]


//// NAT Gateway 

module natGateway 'modules/Networking/natGateway.module.bicep' = if (createNatGw) {
  name: '${applicationName}-NAT-Gateway'
  params: {
    name: '${applicationName}-NATGW'
    location: location
    tags: tags
  }
}


///// VPN Gatway

module vpnGateway 'modules/Networking/vpnGateway.module.bicep' = if (createVpnGw) {
  name: '${applicationName}-VPN-Gateway'
  params: {
    name: '${applicationName}-VpnGW'
    location: location
    vpnGwSubnetId: network.outputs.vpnGatewaySubnetId
    tags: tags
  }
}


//// Load Balancer

module loadBalancer 'modules/Networking/loadBalancer.module.bicep' = if (createLoadBalancer) {
  name: '${applicationName}-LoadBalancer'
  params: {
    name: '${applicationName}-LB'
    isPublic: loadBalancerPublic
    loadBalancerInternalSubnetId: !loadBalancerPublic ? network.outputs.subnets[loadBalancerSubnetIndex].id : null
    location: location
    tags: tags
  }
}

///// Cosmos DB

module cosmosDbNoSQL 'modules/Databases/cosmosDb.noSql.module.bicep' = if (createCosmosDb) {
  name: '${toLower(applicationName)}-cosmosdb'
  params: {
    name: '${toLower(applicationName)}-cosmosdb'
    location: location
    tags: tags
    privateDnsZoneId: first(filter(privateDnsZones.outputs.ids, dnsZone => dnsZone.name == cosmosDbNoSqlDnsZone)).id
    privateEndpointSubnet: network.outputs.privateEndpointSubnetId
  }
}

///// AKS 
//// Defaults to Private Cluster with Azure CNI with Overlay
//// Default Dedicated System Pool with 3 D2s_v5 Nodes
//// Set to GSIS Pod and service CIDRs

module AKS 'modules/Containers/aks.module.bicep' =  [ for (AKSCluster,i) in AKSClusterBatches: {
  name: '${applicationName}-AKS0${ i + 1 }'
  params: {
    name: '${applicationName}-AKS0${ i + 1 }'
    location: location
    azRedundant: AKSCluster.azRedundant
    systemPoolNodeCount: AKSCluster.systemPoolNodeCount
    systemPoolMinNodeCount: AKSCluster.systemPoolMinNodeCount
    systemPoolMaxNodeCount: AKSCluster.systemPoolMaxNodeCount
    systemPoolNodeSize: AKSCluster.systemPoolNodeSize
    applicationPoolNodeCount: AKSCluster.applicationPoolNodeCount
    applicationPoolMinNodeCount: AKSCluster.applicationPoolMinNodeCount
    applicationPoolMaxNodeCount: AKSCluster.applicationPoolMaxNodeCount
    applicationPoolNodeSize: AKSCluster.applicationPoolNodeSize
    applicationPoolSubnetId: network.outputs.AKSSubnetIds[i]
    podCidr: '172.18.0.0/16'
    serviceCidr: '172.17.0.0/16'
    systemPoolSubnetId: network.outputs.AKSSubnetIds[i]
  }
}]


output vnetName string = network.outputs.vnetName
output NSGSubnets array = network.outputs.nsgSubnets


