param name string
param subnetId string
param location string = resourceGroup().location
param tags object = {}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: 'pip-${name}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

output id string = bastionHost.id
output publicIpId string = publicIp.id
output ipAddress string = publicIp.properties.ipAddress
