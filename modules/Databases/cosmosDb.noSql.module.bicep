param name string
param location string = resourceGroup().location
param tags object = {}
// param totalThroughputLimit int = 1000
param zoneRedundant bool = false
param privateDnsZoneId string
param privateEndpointSubnet string

var primaryCosmosLocation = [{
  locationName: location
  failoverPriority: 0
  isZoneRedundant: zoneRedundant
}]

var minName = split(name,'-')[0]
var rgName = split(name,'-')[1]

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: name
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    publicNetworkAccess: 'Disabled'
    enableMultipleWriteLocations: false
    enableAutomaticFailover: false
    isVirtualNetworkFilterEnabled: false
    databaseAccountOfferType: 'Standard'
    minimalTlsVersion: 'Tls12'
    capabilities: [
      {
        name: 'EnableTable'
      }
    ]
    locations: primaryCosmosLocation
    backupPolicy: {
      type: 'Continuous'
      continuousModeProperties: {
         tier: 'Continuous7Days'
      }
    }
  }
}

module privateendpointcosmosdbaccount '../Networking/privateEndpoint.module.bicep' = {
  name: '${minName}-${rgName}-PE_CosmosDB'
  params: {
    name: '${minName}-${rgName}-PE_CosmosDB'
    location: location
    privateDnsZoneId: privateDnsZoneId
    privateLinkServiceId: cosmosDbAccount.id
    subResource: 'Sql'
    subnetId: privateEndpointSubnet
    tags: tags
  }

}



output id string = cosmosDbAccount.id
output name string = cosmosDbAccount.name
