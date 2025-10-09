param location string
param name string
param tags object = {}
@allowed([
  'BlobStorage'
  'BlockBlobStorage'
  'FileStorage'
  'Storage'
  'StorageV2'
])
param kind string = 'StorageV2'
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_LRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param skuName string = 'Standard_GRS'
@allowed([
  'Disabled'
  'Enabled'
])
//Allow or Disallow Public Access - Default to Disabled
param publicNetworkAccess string = 'Disabled'
param isFunctionStorage bool = false
param isVMDiagnostics bool = false
param functionContentShareName string = 'func-content-share'
param keyVaultName string = ''
param keyVaultSecretName string = ''
param privateDnsBlob string = ''
param privateDnsFile string = ''
param privateDnsTable string = ''
param privateDnsQueue string = ''
param privateEndpointSubnet string
param createPrivateEndpointBlob bool = false
param createPrivateEndpointFile bool = false
param createPrivateEndpointTable bool = false
param createPrivateEndpointQueue bool = false

@allowed([
  'Hot'
  'Cool'
  'Premium'
])
param accessTier string = 'Hot'

var createSecretInKeyVault = !empty(keyVaultName) && !empty(keyVaultSecretName)

var rgIndex = indexOf(name, 'rg')
var resourceIndex = indexOf(name, 'sa')

var minName = toUpper(substring(name, 0, rgIndex-1))
var rgName = toUpper(substring(name, rgIndex, resourceIndex - rgIndex))
var resourceName = toUpper(substring(name,resourceIndex,length(name) - resourceIndex))

//Create the storage account
resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  #disable-next-line BCP334
  name: take(toLower('${replace(name, '-', '')}'), 24)
  location: location
  kind: kind
  sku: {
    name: skuName
  }
  tags: union(tags, {
    displayName: name
  })
  properties: {
    accessTier: !isVMDiagnostics ? accessTier : null
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: publicNetworkAccess
    networkAcls: !isVMDiagnostics ? {
      defaultAction: 'Deny'
      bypass: 'None'
    } : null
  }
}

module keyVaultSecret '../Security/keyvault.secret.module.bicep' = if (createSecretInKeyVault) {
  name: 'StorageAccount-KeyVaultSecret-${name}'
  params: {
    keyVaultName: keyVaultName
    name: keyVaultSecretName
    value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value}'
  }
}

//If the storage account is flagged as to be used for function internal storage then create a file share
resource functionContentShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = if (isFunctionStorage) {
  #disable-next-line use-parent-property
  name: '${storage.name}/default/${functionContentShareName}'
}

//create Private Endpoints and link to Private DNS

module privateendpointblob '../Networking/privateEndpoint.module.bicep' = if (createPrivateEndpointBlob) {
  name:  '${minName}-${rgName}-PE_${resourceName}-Blob'
  params:{
    name: '${minName}-${rgName}-PE_${resourceName}-Blob'
    location: location
    privateDnsZoneId: privateDnsBlob
    privateLinkServiceId: storage.id
    subResource: 'blob'
    subnetId: privateEndpointSubnet
    tags: tags
  }
}

module privateendpointfile '../Networking/privateEndpoint.module.bicep' = if (createPrivateEndpointFile) {
  name: '${minName}-${rgName}-PE_${resourceName}-File'
  params:{
    name: '${minName}-${rgName}-PE_${resourceName}-File'
    location: location
    privateDnsZoneId: privateDnsFile
    privateLinkServiceId: storage.id
    subResource: 'file'
    subnetId: privateEndpointSubnet
    tags: tags
  }
}

module privateendpointtable '../Networking/privateEndpoint.module.bicep' = if (createPrivateEndpointTable) {
  name: '${minName}-${rgName}-PE_${resourceName}-Table'
  params:{
    name: '${minName}-${rgName}-PE_${resourceName}-Table'
    location: location
    privateDnsZoneId: privateDnsTable
    privateLinkServiceId: storage.id
    subResource: 'table'
    subnetId: privateEndpointSubnet
    tags: tags
  }
}

module privateendpointqueue '../Networking/privateEndpoint.module.bicep' = if (createPrivateEndpointQueue) {
  name: '${minName}-${rgName}-PE_${resourceName}-Queue'
  params:{
    name: '${minName}-${rgName}-PE_${resourceName}-Queue'
    location: location
    privateDnsZoneId: privateDnsQueue
    privateLinkServiceId: storage.id
    subResource: 'queue'
    subnetId: privateEndpointSubnet
    tags: tags
  }
}


output id string = storage.id
@minLength(3)
@maxLength(24)
output name string = storage.name
// output primaryKey string = listKeys(storage.id, storage.apiVersion).keys[0].value
output primaryEndpoints object = storage.properties.primaryEndpoints
// output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.id, storage.apiVersion).keys[0].value}'
output keyVaultSecretUri string = createSecretInKeyVault ? keyVaultSecret.outputs.uri : ''
output keyVaultSecretReference string = createSecretInKeyVault ? keyVaultSecret.outputs.reference : ''
output storageBlobUri string = storage.properties.primaryEndpoints.blob
