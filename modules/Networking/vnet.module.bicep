param name string
param location string = resourceGroup().location
param tags object = {}
param addressPrefix array
param subnets array
param ddosProtectionPlanId string?

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefix
    }
    subnets: subnets
    enableDdosProtection: !(empty(ddosProtectionPlanId))
    ddosProtectionPlan: !(empty(ddosProtectionPlanId)) ? {
      id: ddosProtectionPlanId
    } : null
  }
  tags: tags
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnets array = vnet.properties.subnets
output delegations array = [for (subnet, i) in subnets: {
  id: vnet.properties.subnets[i].id
  name: vnet.properties.subnets[i].name
  delegations: length(vnet.properties.subnets[i].properties.delegations) > 0 ? vnet.properties.subnets[i].properties.delegations[0].properties.serviceName : 'None'
}]
