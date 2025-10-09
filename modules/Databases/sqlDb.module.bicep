
//Main deployment parameters
@description('Azure region where the resources will be created')
param location string = 'westeurope'
@description('Tags to be applied to the created resources')
param tags object = {}
@description('Name of the existing SQL Server in which to create the DB')
param sqlServerName string 
@description('Name of the SQL Database to deploy')
param sqlDBName string
@description('SQL Database tier')
@allowed([
  'Basic'
  'Standard'
  'Premium'
  'GeneralPurpose'
  'BusinessCritical'
])
param tier string = 'GeneralPurpose'
@description('SQL DB sku and cores')
param skuName string = 'GP_Gen5_2'
@description('SQL DB Collation')
param collation string = 'SQL_Latin1_General_CP1_CI_AS'
@description('Redundancy for the Backups')
param requestedBackupStorageRedundancy string = 'Geo'
@description('SQL DB Max size in bytes')
param maxSizeBytes int = 34359738368 //32GB
@description('Days to retain the DB backups')
param backupRetentionDays int = 15


//Retrieve existing SQL Server(verify resource exists)
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' existing = {
  name: sqlServerName
}

//Create the SQL Database
resource sqlDB 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  name: sqlDBName
  parent: sqlServer
  location: location
  sku: {
    name: skuName
    tier: tier
  }
  properties:{
    collation: collation
    createMode: 'Default'
    requestedBackupStorageRedundancy: requestedBackupStorageRedundancy
    // https://learn.microsoft.com/en-us/sql/t-sql/statements/create-database-transact-sql?view=azuresqldb-current&tabs=sqlpool#maxsize
    // Standard Tier supports specific values up to 100 GB for S0-S2 and 
    // and up to 250GB for S3-S12
    // Defaulting to 30GB on both for now
    maxSizeBytes: tier != 'Standard' ? maxSizeBytes : int(last(skuName)) < 3 ? 32212254720 : 32212254720
    isLedgerOn: false
    maintenanceConfigurationId: subscriptionResourceId('Microsoft.Maintenance/publicMaintenanceConfigurations', 'SQL_Default')
  }
  tags: tags
}

//Configure the backup retention
resource dbBackupRetentionShortTerm 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2022-05-01-preview' = {
  name: 'Default'
  parent: sqlDB
  properties: {
    retentionDays: backupRetentionDays
  }
}

// //Add the provided IP on the firewall

// resource addFirewallIP 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
//   name: '${sqlDBName}-clientIP'
//   parent: sqlServer
//   properties: {
//     endIpAddress: clientIP
//     startIpAddress: clientIP
//   }
// }

output sqlDBId string = sqlDB.id
