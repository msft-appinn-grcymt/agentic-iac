using '../../../azure.deploy.bicep'

var requestNumber = '800'
param intRequestNumber = requestNumber
// General Settings
param agency = 'MIN800'
param project = 'RG800'
param location = 'West Europe'
param tags = {
  applicationNumber: requestNumber
}
//Network settings
param vnetAddressPrefix = ['10.0.0.0/16']
//Subnet.usage ==> VM,VM/PrivateEndpoint,AppService,mySQL,AppGateway,Postgres,VpnGateway, AKS
param subnets = [
  {
     addressPrefix: '10.0.0.0/27' 
     usage: 'AppService'
  }
  {
     addressPrefix: '10.0.0.32/27' 
     usage: 'AppService'
  }
  {
     addressPrefix: '10.0.0.64/26' 
     usage: 'VM/PrivateEndpoint'
  }
]
param enableDdosProtection = false
param createBastion = false
param bastionVnetAddressPrefix = ['10.0.0.0/16']
// Monitoring settings
param createLogAnalytics = false
param createAppInsights = false
// App Service settings
param appServiceCount = 2
param appServiceRuntime = 'linux*DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
param appServiceSkuName = 'P1v3'
// Key Vault settings
param keyVaultCount = 1
// Storage Account settings
param storageAccountCount = 1
param storageBlobPrivateEndpoint = true
param storageFilePrivateEndpoint = false
param storageTablePrivateEndpoint = false
param storageQueuePrivateEndpoint = false
// Application Gateway settings
param createAppGateway = false
param appGwMaxCapacity = 5
param appGWSkuTier = 'WAF_v2'
// SQL settings
param sqlServerCount = 0
param sqlDbCount = 0
param sqlTier = 'Standard'
param sqlSkuName = 'S3'
param sqlServerAdmin = 'localadmin'
param sqlServerPwd = readEnvironmentVariable('IAC_SQL_PWD','') 
// VM Settings
param vmBatches = []
param vmAdminUsername = 'localadmin'
param vmAdminPassword = readEnvironmentVariable('IAC_VM_PWD','') 
//////// MySQL ///////
param mySqlBatches = []
param mySqlAdmin = 'localadmin'
param mySqlAdminPassword = readEnvironmentVariable('IAC_MYSQL_PWD','') 
///// PostgreSQL //////
param postgreSqlBatches = []
param postgresAdmin = 'localadmin'
param postgresAdminPassword = readEnvironmentVariable('IAC_POSTGRES_PWD','')
///// NAT Gateway //////
param createNatGw = false
///// VPN Gateway //////
param createVpnGw = false
///// Load Balancer //////
param createLoadBalancer = false
param loadBalancerPublic = false
param loadBalancerSubnetIndex = 0
///// Cosmos DB for NoSQL //////
param createCosmosDb = false
///// AKS ///////
param AKSClusterBatches = []
