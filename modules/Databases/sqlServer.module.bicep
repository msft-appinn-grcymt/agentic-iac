param name string
param location string = resourceGroup().location
param tags object = {}
@secure()
param administratorLogin string
@secure()
param administratorLoginPassword string
param privateDnsZoneId string
param privateEndpointSubnet string

//Create the SQL Server
resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

var minName = split(name,'-')[0]
var rgName = split(name,'-')[1]
var resourceName = split(name,'-')[2]

//Create the private endpoint and add the record to the private DNS zone
module privateendpoointsql '..//Networking/privateEndpoint.module.bicep' = {
  name: '${minName}-${rgName}-PE-${resourceName}'
  params:{
    name: '${minName}-${rgName}-PE-${resourceName}'
    location: location
    privateDnsZoneId: privateDnsZoneId
    privateLinkServiceId: sqlServer.id
    subResource: 'sqlServer'
    subnetId: privateEndpointSubnet
    tags: tags
  }
}

output sqlServerName string = sqlServer.name
