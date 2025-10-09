@description('Required. The name of the storage account, will be sanitized.')
param name string
@description('The location of the storage account, defaults to the resource group\'s location.')
param location string = resourceGroup().location
@description('Optional. Tags to be added to the resource, .')
param tags object = {}
@description('SKU of the Static Web App')
@allowed([
  'Standard'
  'Free'
])
param skuName string = 'Standard'
@description('Allow Config File Updates')
param allowConfigFileUpdates bool = true
@description('Enabled enterprise grade CDN')
param enterpriseGradeCdnStatus string = 'Disabled'
@description('Repository provider - set to none to initialize')
param provider string = 'None'
@description('Staging Environment Policy')
param stagingEnvironmentPolicy string = 'Enabled'


resource staticWebApp 'Microsoft.Web/staticSites@2022-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuName
  }
  properties: {
    allowConfigFileUpdates: allowConfigFileUpdates
    enterpriseGradeCdnStatus: enterpriseGradeCdnStatus
    provider: provider
    stagingEnvironmentPolicy: stagingEnvironmentPolicy
  }
}

output defaultHostname string = staticWebApp.properties.defaultHostname
output id string = staticWebApp.id

