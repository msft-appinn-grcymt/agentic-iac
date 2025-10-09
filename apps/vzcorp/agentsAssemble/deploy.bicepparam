using './main.bicep'

// Request metadata
var requestNumber = 'vzcorp-assemble-001'

// Organization and project
param organization = 'vzcorp'
param project = 'agentsAssemble'

// Location
param location = 'westeurope'

// Tags
param tags = {
  applicationNumber: requestNumber
  organization: organization
  project: project
  environment: 'Production'
}

// Network configuration
param vnetAddressPrefixes = [
  '10.0.0.0/16'
]

param subnetDefinitions = [
  {
    name: 'snet-app1'
    usage: 'AppService'
    addressPrefix: '10.0.0.0/27'
  }
  {
    name: 'snet-app2'
    usage: 'AppService'
    addressPrefix: '10.0.0.32/27'
  }
  {
    name: 'snet-pe'
    usage: 'PrivateEndpoint'
    addressPrefix: '10.0.1.0/26'
  }
]

// Storage Account
param storageAccountName = 'stvcorpassemble001'

// Key Vault
param keyVaultName = 'kv-vcorp-assemble'

// App Service Plan
param appServicePlanSku = 'P1v3'
param appServicePlanInstances = 2
