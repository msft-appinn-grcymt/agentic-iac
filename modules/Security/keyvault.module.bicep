param name string
param location string = resourceGroup().location
param tags object = {}
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'
@description('Optional. Array of access policy configurations, schema ref: https://docs.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults/accesspolicies?tabs=json#microsoftkeyvaultvaultsaccesspolicies-object')
param accessPolicies array = []
@description('Optional. Secrets object with name/value pairs')
@secure()
param secrets object = {}
param privateEndpointSubResource string = 'vault'
param privateEndpointSubnet string
param privateDnsZoneId string
param networkACLdefaultAction string = 'Deny'
param publicNetworkAccess string = 'disabled'
param enableForDeployment bool = true

var minName = split(name,'-')[0]
var rgName = split(name,'-')[1]
var resourceName = split(name,'-')[2]

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: name
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: skuName
    }
    accessPolicies: accessPolicies
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: networkACLdefaultAction
    }
    createMode: 'default'
    publicNetworkAccess: publicNetworkAccess
    enabledForDeployment: enableForDeployment
  }
  tags: tags
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = [for secret in items(secrets): {
  parent: keyVault
  name: secret.value.name
  properties: {
    value: secret.value.value
  }
}]

//Private Endpoint

//create the private endpoints and dns zone groups

module privateendpointkeyvault '../Networking/privateEndpoint.module.bicep' = {
  name: '${minName}-${rgName}-PE-${resourceName}'
  params:{
    name: '${minName}-${rgName}-PE-${resourceName}'
    location: location
    privateDnsZoneId: privateDnsZoneId
    privateLinkServiceId: keyVault.id
    subResource: privateEndpointSubResource
    subnetId: privateEndpointSubnet
    tags: tags
  }
}

output id string = keyVault.id
output name string = keyVault.name
