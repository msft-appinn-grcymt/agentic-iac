param name string
param location string = resourceGroup().location
param tags object = {}

var minName = split(name,'-')[0]
var rgName = split(name,'-')[1]

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${minName}-${rgName}-NatGW-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natgateway 'Microsoft.Network/natGateways@2023-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: publicIp.id
      }
    ]
  }
}


