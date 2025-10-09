param name string
param location string = resourceGroup().location
param tags object = {}
param skuName string = 'Standard_D2ads_v5'
param skuTier string = 'GeneralPurpose'
param administratorLogin string = 'mysqladmin'
@secure()
param administratorLoginPassword string 
param iops int = 492
param storageSizeGB int = 64
param version string = '8.0.21'
param backupRetentionDays int = 7
param geoRedundantBackup string = 'Enabled'
param highAvailabilityMode string = 'Disabled'
param subnetId string
param privateDnsZoneId string

resource mySQLFlexible 'Microsoft.DBforMySQL/flexibleServers@2023-10-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      autoGrow: 'Enabled'
      iops: iops
      storageSizeGB: storageSizeGB
      }
    createMode: 'Default'
    version: version
    backup: {
        backupRetentionDays: backupRetentionDays
        geoRedundantBackup: geoRedundantBackup
      }
    highAvailability: {
        mode: highAvailabilityMode
      }
    network: {
        publicNetworkAccess: 'Disabled'
        delegatedSubnetResourceId: subnetId
        privateDnsZoneResourceId: privateDnsZoneId
      }
    }
  }

