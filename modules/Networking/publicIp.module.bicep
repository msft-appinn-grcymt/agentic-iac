param name string
param location string = resourceGroup().location
param tags object = {}
@description('Public IP SKU')
@allowed([
  'Basic'
  'Standard'
])
param skuName string = 'Standard'

@description('The public IP address allocation method')
@allowed([
  'Static'
  'Dynamic'
])
param publicIPAllocationMethod string = 'Static'

@description('The domain name label. The concatenation of the domain name label and the regionalized DNS zone make up the fully qualified domain name associated with the public IP address. If a domain name label is specified, an A DNS record is created for the public IP in the Microsoft Azure DNS system.')
param dnsLabelPrefix string

resource pip 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

output pipName string = pip.name
output pipId string = pip.id
