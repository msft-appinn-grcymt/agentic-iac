param name string
param location string = resourceGroup().location
param tags object = {}
param vpnGwSubnetId string
param gatewaySku string = 'VpnGw1'


var minName = split(name,'-')[0]
var rgName = split(name,'-')[1]

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${minName}-${rgName}-VpnGW-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource vnet2Gateway 'Microsoft.Network/virtualNetworkGateways@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    ipConfigurations: [
      {
        name: 'vNet2GatewayConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vpnGwSubnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: false
    activeActive: false
  }
}

