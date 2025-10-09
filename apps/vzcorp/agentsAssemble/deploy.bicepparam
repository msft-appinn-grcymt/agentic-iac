using './main.bicep'

// ============================================================================
// Request Metadata
// ============================================================================
var requestNumber = 'vzcorp-assemble-001'

// ============================================================================
// Core Parameters
// ============================================================================
param organization = 'vzcorp'
param project = 'agentsAssemble'
param location = 'westeurope'

// ============================================================================
// Tags
// ============================================================================
param tags = {
  applicationNumber: requestNumber
  organization: organization
  project: project
  environment: 'Production'
}

// ============================================================================
// Network Configuration
// ============================================================================
param vnetAddressPrefixes = [
  '10.0.0.0/16'
]

param subnetDefinitions = [
  {
    name: 'snet-app1'
    usage: 'AppService1'
    addressPrefix: '10.0.0.0/27'
  }
  {
    name: 'snet-app2'
    usage: 'AppService2'
    addressPrefix: '10.0.0.32/27'
  }
  {
    name: 'snet-pe'
    usage: 'PrivateEndpoint'
    addressPrefix: '10.0.1.0/26'
  }
]

// ============================================================================
// Resource Names
// ============================================================================
param storageAccountName = 'stvcorpassemble001'
param keyVaultName = 'kv-vcorp-assemble'
param appServicePlanName = 'asp-vzcorp-agentsAssemble'
param webAppName = 'app-vzcorp-agentsAssemble'
param logAnalyticsName = 'log-vzcorp-agentsAssemble'
param appInsightsName = 'appi-vzcorp-agentsAssemble'
