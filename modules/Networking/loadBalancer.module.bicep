param name string
param location string = resourceGroup().location
param tags object = {}
param isPublic bool
param loadBalancerInternalSubnetId string?



var minName = split(name,'-')[0]
var rgName = split(name,'-')[1]

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = if (isPublic) {
  name: '${minName}-${rgName}-LB-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

var frontendIPConfigurations = isPublic ? [
  {
    properties: {
      privateIPAllocationMethod: 'Dynamic'
      publicIPAddress: {
        id: publicIp.id
      }
    }
    name: 'LoadBalancerFrontend'
  }] : [
      {
        properties: {
          subnet: {
            id: loadBalancerInternalSubnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
        name: 'LoadBalancerFrontend'
      }
    ]

resource loadBalancer 'Microsoft.Network/loadBalancers@2023-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: frontendIPConfigurations
  }
}

