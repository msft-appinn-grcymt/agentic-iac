// targetScope = 'subscription'
@description('Internal request number')
param intRequestNumber string
@description('Name of the agency')
param agency string
@description('Name of the agency project/RG')
param project string
@description('Tags to be assigned to all resources')
param tags object = {}
@description('Enable DDOS protection flag')
param enableDdosProtection bool = false
@description('The existing DDOS protection plan to use for the VNet')
param ddosProtectionPlanName string = 'GSIS-DDoS'
@description('Location of the resources')
param location string 
@description('Address prefix for the VNet')
param vnetAddressPrefix array
@description('Subnets for the VNet')
param subnets array
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
param vmBatches array = []
@description('VM Admin user')
@secure()
param vmAdminUsername string 
@description('VM Admin user password')
@secure()
param vmAdminPassword string 
@description('The version of the platform image or marketplace image used to create the virtual machine')
param vmOSVersion string = 'latest'
@description('Number of MySQL Flexible servers instances to create')
param mySqlBatches array = []
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
@description('PostgreSQL Flexible Servers to create')
param postgreSqlBatches array = []
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


// // Resource group which is the scope for the main deployment below
// resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
//   name: '${agency}-${project}'
//   location: location
//   tags: tags
// }

// Main deployment has all the resources to be deployed for 
// a workload in the scope of the specific resource group

module main 'main.bicep' = {
  // scope: resourceGroup(rg.name)
  name: 'MainDeployment'
  
  params: {
    applicationName: '${agency}-${project}'
    location: location
    tags: tags
    intRequestNumber: intRequestNumber
    enableDdosProtection: enableDdosProtection
    ddosProtectionPlanName: ddosProtectionPlanName
    vnetAddressPrefix: vnetAddressPrefix
    subnets: subnets
    createBastion: createBastion
    bastionVnetAddressPrefix: bastionVnetAddressPrefix
    createLogAnalytics: createLogAnalytics
    existingLogAnalyticsWorkspaceId: existingLogAnalyticsWorkspaceId
    createAppInsights: createAppInsights
    appServiceCount: appServiceCount
    appServiceRuntime: appServiceRuntime
    appServiceSkuName: appServiceSkuName
    keyVaultCount: keyVaultCount
    storageAccountCount: storageAccountCount
    storageBlobPrivateEndpoint: storageBlobPrivateEndpoint
    storageFilePrivateEndpoint: storageFilePrivateEndpoint
    storageTablePrivateEndpoint: storageTablePrivateEndpoint
    storageQueuePrivateEndpoint: storageQueuePrivateEndpoint
    createAppGateway: createAppGateway
    appGWSkuTier: appGWSkuTier
    appGwMaxCapacity: appGwMaxCapacity
    sqlServerCount: sqlServerCount
    sqlDbCount: sqlDbCount
    sqlSkuName: sqlSkuName
    sqlTier: sqlTier
    sqlServerAdmin: sqlServerAdmin
    sqlServerPwd: sqlServerPwd
    vmBatches: vmBatches
    vmAdminUsername: vmAdminUsername
    vmAdminPassword: vmAdminPassword
    vmOSVersion: vmOSVersion
    mySqlBatches: mySqlBatches
    mySqlAdmin: mySqlAdmin
    mySqlAdminPassword: mySqlAdminPassword
    postgreSqlBatches: postgreSqlBatches
    postgresAdmin: postgresAdmin
    postgresAdminPassword: postgresAdminPassword
    createNatGw: createNatGw
    createVpnGw: createVpnGw
    createLoadBalancer: createLoadBalancer
    loadBalancerPublic: loadBalancerPublic
    loadBalancerSubnetIndex: loadBalancerSubnetIndex
    createCosmosDb: createCosmosDb
    AKSClusterBatches:AKSClusterBatches
  }
  
}

/*var appname = '${agency}-${project}'
output applicationName string = appname
var minName = split(appname, '-')[0]
output minstr string = minName
*/

// Customize outputs as required from the main deployment module
output vnetName string = main.outputs.vnetName
//output subnetsCount int = length(subnets)
output nsgSubnets array = main.outputs.NSGSubnets
