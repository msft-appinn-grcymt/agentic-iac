targetScope = 'subscription'

// Parameters
param organization string
param project string
param location string
param tags object
param vnetAddressPrefixes array
param subnetDefinitions array
param storageAccountName string
param keyVaultName string
param appServicePlanSku string
param appServicePlanInstances int

// Derived variables
var workloadName = '${organization}-${project}'
var resourceGroupName = workloadName

// Resource Group
module workloadRg 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'rg-${workloadName}'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

// Network Security Groups
module nsgs 'br/public:avm/res/network/network-security-group:0.5.0' = [
  for (subnet, i) in subnetDefinitions: {
    name: 'nsg-${workloadName}-${subnet.usage}-${i}'
    scope: resourceGroup(resourceGroupName)
    params: {
      name: '${workloadName}-${subnet.usage}-nsg'
      location: location
      securityRules: []
      tags: tags
    }
    dependsOn: [
      workloadRg
    ]
  }
]

// Virtual Network with Subnets
module vnet 'br/public:avm/res/network/virtual-network:0.7.0' = {
  name: 'vnet-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${workloadName}-vnet'
    location: location
    addressPrefixes: vnetAddressPrefixes
    subnets: [
      for (subnet, i) in subnetDefinitions: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
        networkSecurityGroupResourceId: nsgs[i].outputs.resourceId
        delegations: subnet.usage == 'AppService' ? [
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
  dependsOn: [
    workloadRg
  ]
}

// Log Analytics Workspace
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
  name: 'law-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${workloadName}-law'
    location: location
    tags: tags
  }
  dependsOn: [
    workloadRg
  ]
}

// Application Insights
module appInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: 'appi-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${workloadName}-appi'
    location: location
    workspaceResourceId: logAnalytics.outputs.resourceId
    tags: tags
  }
  dependsOn: [
    workloadRg
  ]
}

// Private DNS Zones with VNet Links
module privateDnsZoneBlob 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  name: 'pdz-blob-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'privatelink.blob.core.windows.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        name: 'vnetlink-blob'
        virtualNetworkResourceId: vnet.outputs.resourceId
        registrationEnabled: false
      }
    ]
    tags: tags
  }
  dependsOn: [
    workloadRg
  ]
}

module privateDnsZoneVault 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  name: 'pdz-vault-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'privatelink.vaultcore.azure.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        name: 'vnetlink-vault'
        virtualNetworkResourceId: vnet.outputs.resourceId
        registrationEnabled: false
      }
    ]
    tags: tags
  }
  dependsOn: [
    workloadRg
  ]
}

module privateDnsZoneWebsites 'br/public:avm/res/network/private-dns-zone:0.8.0' = {
  name: 'pdz-websites-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: 'privatelink.azurewebsites.net'
    location: 'global'
    virtualNetworkLinks: [
      {
        name: 'vnetlink-websites'
        virtualNetworkResourceId: vnet.outputs.resourceId
        registrationEnabled: false
      }
    ]
    tags: tags
  }
  dependsOn: [
    workloadRg
  ]
}

// Storage Account
module storageAccount 'br/public:avm/res/storage/storage-account:0.27.0' = {
  name: 'st-${workloadName}'
  scope: resourceGroup(resourceGroupName)
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
    }
    tags: tags
  }
  dependsOn: [
    workloadRg
  ]
}

// Private Endpoint for Storage Blob
module storagePrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  name: 'pe-blob-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${workloadName}-st-blob-pe'
    location: location
    subnetResourceId: vnet.outputs.subnetResourceIds[2] // Private endpoint subnet
    privateLinkServiceConnections: [
      {
        name: '${workloadName}-st-blob-conn'
        properties: {
          privateLinkServiceId: storageAccount.outputs.resourceId
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          name: 'blob-dns-config'
          properties: {
            privateDnsZoneId: privateDnsZoneBlob.outputs.resourceId
          }
        }
      ]
    }
    tags: tags
  }
}

// Key Vault
module keyVault 'br/public:avm/res/key-vault/vault:0.13.0' = {
  name: 'kv-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: keyVaultName
    location: location
    sku: 'standard'
    enablePurgeProtection: true
    enableSoftDelete: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    tags: tags
  }
  dependsOn: [
    workloadRg
  ]
}

// Private Endpoint for Key Vault
module keyVaultPrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  name: 'pe-kv-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${workloadName}-kv-pe'
    location: location
    subnetResourceId: vnet.outputs.subnetResourceIds[2] // Private endpoint subnet
    privateLinkServiceConnections: [
      {
        name: '${workloadName}-kv-conn'
        properties: {
          privateLinkServiceId: keyVault.outputs.resourceId
          groupIds: [
            'vault'
          ]
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          name: 'vault-dns-config'
          properties: {
            privateDnsZoneId: privateDnsZoneVault.outputs.resourceId
          }
        }
      ]
    }
    tags: tags
  }
}

// App Service Plan
module appServicePlan 'br/public:avm/res/web/serverfarm:0.5.0' = {
  name: 'asp-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${workloadName}-asp'
    location: location
    skuName: appServicePlanSku
    skuCapacity: appServicePlanInstances
    kind: 'linux'
    reserved: true
    tags: tags
  }
  dependsOn: [
    workloadRg
  ]
}

// Web App 1
module webApp1 'br/public:avm/res/web/site:0.19.0' = {
  name: 'app1-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${workloadName}-app1'
    location: location
    kind: 'app,linux'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetId: vnet.outputs.subnetResourceIds[0] // App Service subnet 1
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      vnetRouteAllEnabled: true
      alwaysOn: true
    }
    appInsightResourceId: appInsights.outputs.resourceId
    tags: tags
  }
}

// Web App 2
module webApp2 'br/public:avm/res/web/site:0.19.0' = {
  name: 'app2-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${workloadName}-app2'
    location: location
    kind: 'app,linux'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    httpsOnly: true
    publicNetworkAccess: 'Disabled'
    virtualNetworkSubnetId: vnet.outputs.subnetResourceIds[1] // App Service subnet 2
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      vnetRouteAllEnabled: true
      alwaysOn: true
    }
    appInsightResourceId: appInsights.outputs.resourceId
    tags: tags
  }
}

// Private Endpoint for Web App 1
module webApp1PrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  name: 'pe-app1-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${workloadName}-app1-pe'
    location: location
    subnetResourceId: vnet.outputs.subnetResourceIds[2] // Private endpoint subnet
    privateLinkServiceConnections: [
      {
        name: '${workloadName}-app1-conn'
        properties: {
          privateLinkServiceId: webApp1.outputs.resourceId
          groupIds: [
            'sites'
          ]
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          name: 'websites-dns-config'
          properties: {
            privateDnsZoneId: privateDnsZoneWebsites.outputs.resourceId
          }
        }
      ]
    }
    tags: tags
  }
}

// Private Endpoint for Web App 2
module webApp2PrivateEndpoint 'br/public:avm/res/network/private-endpoint:0.11.0' = {
  name: 'pe-app2-${workloadName}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: '${workloadName}-app2-pe'
    location: location
    subnetResourceId: vnet.outputs.subnetResourceIds[2] // Private endpoint subnet
    privateLinkServiceConnections: [
      {
        name: '${workloadName}-app2-conn'
        properties: {
          privateLinkServiceId: webApp2.outputs.resourceId
          groupIds: [
            'sites'
          ]
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          name: 'websites-dns-config'
          properties: {
            privateDnsZoneId: privateDnsZoneWebsites.outputs.resourceId
          }
        }
      ]
    }
    tags: tags
  }
}

// Outputs
output resourceGroupName string = resourceGroupName
output vnetName string = vnet.outputs.name
output nsgSubnets array = [
  for (subnet, i) in subnetDefinitions: {
    subNetName: subnet.name
    nsgName: '${workloadName}-${subnet.usage}-nsg'
  }
]
