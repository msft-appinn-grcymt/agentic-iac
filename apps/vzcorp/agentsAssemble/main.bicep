targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================
param organization string
param project string
param location string
param tags object
param vnetAddressPrefixes array
param subnetDefinitions array
param storageAccountName string
param keyVaultName string
param appServicePlanName string
param webAppName string
param logAnalyticsName string
param appInsightsName string

// ============================================================================
// Variables
// ============================================================================
var workloadName = '${organization}-${project}'

// ============================================================================
// Log Analytics Workspace - AVM 0.12
// ============================================================================
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.12' = {
  name: 'log-${workloadName}'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
}

// ============================================================================
// Application Insights - AVM 0.6
// ============================================================================
module appInsights 'br/public:avm/res/insights/component:0.6' = {
  name: 'appi-${workloadName}'
  params: {
    name: appInsightsName
    location: location
    workspaceResourceId: logAnalytics.outputs.resourceId
    tags: tags
  }
}

// ============================================================================
// Network Security Groups - AVM 0.5
// ============================================================================
module nsgAppService1 'br/public:avm/res/network/network-security-group:0.5' = {
  name: 'nsg-${workloadName}-app1'
  params: {
    name: '${workloadName}-app1-nsg'
    location: location
    tags: tags
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

module nsgAppService2 'br/public:avm/res/network/network-security-group:0.5' = {
  name: 'nsg-${workloadName}-app2'
  params: {
    name: '${workloadName}-app2-nsg'
    location: location
    tags: tags
    securityRules: [
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

module nsgPrivateEndpoint 'br/public:avm/res/network/network-security-group:0.5' = {
  name: 'nsg-${workloadName}-pe'
  params: {
    name: '${workloadName}-pe-nsg'
    location: location
    tags: tags
    securityRules: []
  }
}

// ============================================================================
// Virtual Network - AVM 0.7
// ============================================================================
module vnet 'br/public:avm/res/network/virtual-network:0.7' = {
  name: 'vnet-${workloadName}'
  params: {
    name: '${workloadName}-vnet'
    location: location
    addressPrefixes: vnetAddressPrefixes
    subnets: [
      for subnet in subnetDefinitions: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
        networkSecurityGroupResourceId: subnet.usage == 'AppService1' ? nsgAppService1.outputs.resourceId : subnet.usage == 'AppService2' ? nsgAppService2.outputs.resourceId : nsgPrivateEndpoint.outputs.resourceId
        delegations: subnet.usage == 'AppService1' || subnet.usage == 'AppService2' ? [
          {
            name: 'delegation'
            properties: {
              serviceName: 'Microsoft.Web/serverFarms'
            }
          }
        ] : []
      }
    ]
    tags: tags
  }
}

// ============================================================================
// Storage Account - AVM 0.27
// ============================================================================
module storageAccount 'br/public:avm/res/storage/storage-account:0.27' = {
  name: 'st-${workloadName}'
  params: {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_ZRS'
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    tags: tags
  }
}

// ============================================================================
// Private DNS Zone for Storage Blob - AVM 0.8
// ============================================================================
module privateDnsZoneBlob 'br/public:avm/res/network/private-dns-zone:0.8' = {
  name: 'pdns-blob-${workloadName}'
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    tags: tags
  }
}

module privateDnsZoneLinkBlob 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.8' = {
  name: 'pdns-link-blob-${workloadName}'
  params: {
    privateDnsZoneName: privateDnsZoneBlob.outputs.name
    virtualNetworkResourceId: vnet.outputs.resourceId
    tags: tags
  }
}

// ============================================================================
// Private Endpoint for Storage Blob - AVM 0.11
// ============================================================================
module privateEndpointBlob 'br/public:avm/res/network/private-endpoint:0.11' = {
  name: 'pe-blob-${workloadName}'
  params: {
    name: 'pe-${storageAccountName}-blob'
    location: location
    subnetResourceId: vnet.outputs.subnetResourceIds[2]
    privateLinkServiceConnections: [
      {
        name: 'pe-${storageAccountName}-blob'
        properties: {
          privateLinkServiceId: storageAccount.outputs.resourceId
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'default'
      privateDnsZoneGroupConfigs: [
        {
          name: 'privatelink-blob-core-windows-net'
          properties: {
            privateDnsZoneId: privateDnsZoneBlob.outputs.resourceId
          }
        }
      ]
    }
    tags: tags
  }
}

// ============================================================================
// Key Vault - AVM 0.13
// ============================================================================
module keyVault 'br/public:avm/res/key-vault/vault:0.13' = {
  name: 'kv-${workloadName}'
  params: {
    name: keyVaultName
    location: location
    sku: 'standard'
    enableSoftDelete: true
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    tags: tags
  }
}

// ============================================================================
// Private DNS Zone for Key Vault - AVM 0.8
// ============================================================================
module privateDnsZoneKeyVault 'br/public:avm/res/network/private-dns-zone:0.8' = {
  name: 'pdns-kv-${workloadName}'
  params: {
    name: 'privatelink.vaultcore.azure.net'
    tags: tags
  }
}

module privateDnsZoneLinkKeyVault 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.8' = {
  name: 'pdns-link-kv-${workloadName}'
  params: {
    privateDnsZoneName: privateDnsZoneKeyVault.outputs.name
    virtualNetworkResourceId: vnet.outputs.resourceId
    tags: tags
  }
}

// ============================================================================
// Private Endpoint for Key Vault - AVM 0.11
// ============================================================================
module privateEndpointKeyVault 'br/public:avm/res/network/private-endpoint:0.11' = {
  name: 'pe-kv-${workloadName}'
  params: {
    name: 'pe-${keyVaultName}'
    location: location
    subnetResourceId: vnet.outputs.subnetResourceIds[2]
    privateLinkServiceConnections: [
      {
        name: 'pe-${keyVaultName}'
        properties: {
          privateLinkServiceId: keyVault.outputs.resourceId
          groupIds: [
            'vault'
          ]
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'default'
      privateDnsZoneGroupConfigs: [
        {
          name: 'privatelink-vaultcore-azure-net'
          properties: {
            privateDnsZoneId: privateDnsZoneKeyVault.outputs.resourceId
          }
        }
      ]
    }
    tags: tags
  }
}

// ============================================================================
// App Service Plan - AVM 0.5
// ============================================================================
module appServicePlan 'br/public:avm/res/web/serverfarm:0.5' = {
  name: 'asp-${workloadName}'
  params: {
    name: appServicePlanName
    location: location
    skuName: 'P1v3'
    skuCapacity: 2
    kind: 'Linux'
    reserved: true
    tags: tags
  }
}

// ============================================================================
// Private DNS Zone for Web Apps - AVM 0.8
// ============================================================================
module privateDnsZoneWebApp 'br/public:avm/res/network/private-dns-zone:0.8' = {
  name: 'pdns-webapp-${workloadName}'
  params: {
    name: 'privatelink.azurewebsites.net'
    tags: tags
  }
}

module privateDnsZoneLinkWebApp 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.8' = {
  name: 'pdns-link-webapp-${workloadName}'
  params: {
    privateDnsZoneName: privateDnsZoneWebApp.outputs.name
    virtualNetworkResourceId: vnet.outputs.resourceId
    tags: tags
  }
}

// ============================================================================
// Web App - AVM 0.19
// ============================================================================
module webApp 'br/public:avm/res/web/site:0.19' = {
  name: 'app-${workloadName}'
  params: {
    name: webAppName
    location: location
    kind: 'app,linux'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetId: vnet.outputs.subnetResourceIds[0]
    siteConfig: {
      vnetRouteAllEnabled: true
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    appInsightResourceId: appInsights.outputs.resourceId
    tags: tags
  }
}

// ============================================================================
// Private Endpoint for Web App - AVM 0.11
// ============================================================================
module privateEndpointWebApp 'br/public:avm/res/network/private-endpoint:0.11' = {
  name: 'pe-webapp-${workloadName}'
  params: {
    name: 'pe-${webAppName}'
    location: location
    subnetResourceId: vnet.outputs.subnetResourceIds[2]
    privateLinkServiceConnections: [
      {
        name: 'pe-${webAppName}'
        properties: {
          privateLinkServiceId: webApp.outputs.resourceId
          groupIds: [
            'sites'
          ]
        }
      }
    ]
    privateDnsZoneGroup: {
      name: 'default'
      privateDnsZoneGroupConfigs: [
        {
          name: 'privatelink-azurewebsites-net'
          properties: {
            privateDnsZoneId: privateDnsZoneWebApp.outputs.resourceId
          }
        }
      ]
    }
    tags: tags
  }
}

// ============================================================================
// Outputs
// ============================================================================
output vnetName string = vnet.outputs.name
output nsgSubnets array = [
  {
    subNetName: subnetDefinitions[0].name
    nsgName: nsgAppService1.outputs.name
  }
  {
    subNetName: subnetDefinitions[1].name
    nsgName: nsgAppService2.outputs.name
  }
  {
    subNetName: subnetDefinitions[2].name
    nsgName: nsgPrivateEndpoint.outputs.name
  }
]
output storageAccountName string = storageAccount.outputs.name
output keyVaultName string = keyVault.outputs.name
output appServicePlanName string = appServicePlan.outputs.name
output webAppName string = webApp.outputs.name
