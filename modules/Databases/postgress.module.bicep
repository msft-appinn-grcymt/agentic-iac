param name string
param location string 
param tags object
@secure()
param administratorLogin string
@secure()
param administratorLoginPassword string

param skuTier string 
param storageSizeGB int = 128
param skuName string 
param version string = '12'
param postgresqlSubnetId string 
param postgresqlDnsZoneId string 

resource serverName_resource 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: name
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  tags: tags
  properties: {
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    network: {
      delegatedSubnetResourceId: postgresqlSubnetId
      privateDnsZoneArmResourceId: postgresqlDnsZoneId
    }
    highAvailability: {
      mode: 'Disabled'
    }
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Enabled'
    }
  }
}
