param vnetName string
param peerVnetName string
// param peerAddressPrefix array
// param includeBastion bool = true
param peerVnetResourceGroup string


resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetName
}

resource peerVnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: peerVnetName
  scope: resourceGroup(peerVnetResourceGroup)
}

resource vnetPeeringToBastion 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-04-01' = {
  name: '${vnetName}-${peerVnetName}'
  parent: vnet
  properties: {
    allowForwardedTraffic: false
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    doNotVerifyRemoteGateways: false
    // remoteAddressSpace: {
    //   addressPrefixes: peerAddressPrefix
    // }
    remoteVirtualNetwork: {
      id: peerVnet.id
    }
    // remoteVirtualNetworkAddressSpace: {
    //   addressPrefixes: peerAddressPrefix
    //  }
    useRemoteGateways: false
  }
}


