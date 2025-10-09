// param name string
param dnsZones array
param tags object = {}
param registrationEnabled bool = false
param vnetIds array


resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = [ for dnsZone in dnsZones : {
  name: dnsZone
  location: 'Global'
  tags: tags  
}]

module privateDnsZoneLinks 'privateDnsZoneLink.module.bicep' =  [ for (dnsZone,i) in dnsZones : if (!empty(vnetIds)) {
  name: 'PrvDnsZoneLinks-Deployment-${dnsZone}'  
  params: {
    privateDnsZoneName: privateDnsZone[i].name
    vnetIds: vnetIds
    registrationEnabled: registrationEnabled
    tags: tags
  }
}]

output ids array = [ for (item,i) in dnsZones : {
  id: privateDnsZone[i].id
  name: privateDnsZone[i].name
}]

