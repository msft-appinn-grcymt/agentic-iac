param name string
param location string = resourceGroup().location
param tags object = {}
param allowHttpInbound bool = false
param allowHttpsInbound bool = false
param allowHttpsOutbound bool = false
param allowSsh bool = false
param azureLoadTesting bool = false
param applicationGateway bool = false

//Object with NSG security rules properties set if we configured enabling incoming http access
//Otherwise empty
var httpSecurityRule = allowHttpInbound ? [
  {
    name: 'AllowHTTPInbound'
    properties: {
      description: 'Allow inbound http traffic from everywhere'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 1000
      direction: 'Inbound'
    }
  } ] : []
//Object with NSG security rules properties set if we configured enabling incoming https access
//Otherwise empty
var httpsSecurityRule = allowHttpsInbound ? [
  {
    name: 'AllowHTTPSInbound'
    properties: {
      description: 'Allow inbound HTTPS traffic from everywhere'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  } ] : []
//Object with NSG security rules properties set if we configured enabling incoming ssh access
//Otherwise empty
var sshSecurityRule = allowSsh ? [
  {
    name: 'AllowSSHInbound'
    properties: {
      description: 'Allow inbound ssh from everywhere'
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '22'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 200
      direction: 'Inbound'
    }
  } ] : []
//Object with NSG security rules properties set if we configured enabling outgoing https access
//Otherwise empty      
var httpsOutboundSecurityRule = allowHttpsOutbound ? [
  {
    name: 'AllowHTTPSInbound'
    properties: {
      description: 'Allow outbound traffic for https ssh from everywhere'
      protocol: 'TCP'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 500
      direction: 'Outbound'
    }
  } ] : []

//Object with NSG security rules properties set needed for Appligation Gateway
//Otherwise empty

var applicationGatewayRules = applicationGateway ? [
  {
    name: 'HealthProbes'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '65200-65535'
      sourceAddressPrefix: 'GatewayManager'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
  {
    name: 'Allow_TLS'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 110
      direction: 'Inbound'
    }
  }
  {
    name: 'Allow_HTTP'
    properties: {
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 111
      direction: 'Inbound'
    }
  }
  {
    name: 'Allow_AzureLoadBalancer'
    properties: {
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 120
      direction: 'Inbound'
    }
  }
] : []

//Object with NSG security rules properties set needed for load testing subnet per https://learn.microsoft.com/en-us/azure/load-testing/how-to-test-private-endpoint
//Otherwise empty
var loadTestingSecurityRules = azureLoadTesting ? [
  {
    name: 'batch-node-management-inbound'
    properties: {
      description: 'Create, update, and delete of Azure Load Testing compute instances.'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '29876-29877'
      sourceAddressPrefix: 'BatchNodeManagement'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 100
      direction: 'Inbound'
    }
  }
  {
    name: 'azure-load-testing-inbound'
    properties: {
      description: 'Create, update, and delete of Azure Load Testing compute instances.'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '8080'
      sourceAddressPrefix: 'AzureLoadTestingInstanceManagement'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 110
      direction: 'Inbound'
    }
  }
  {
    name: 'azure-load-testing-outbound'
    properties: {
      description: 'Used for various operations involved in orchestrating a load tests.'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRange: '*'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '*'
      access: 'Allow'
      priority: 120
      direction: 'Outbound'
    }
  } ] : []

//Combine all the objects to define the complete set of NSG rules and attach them to the resource
var securityRules = concat(httpSecurityRule, httpsSecurityRule, httpsOutboundSecurityRule, sshSecurityRule, applicationGatewayRules, loadTestingSecurityRules)

resource nsg 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: name
  location: location
  properties: {
    securityRules: securityRules
  }
  tags: tags
}

output nsgId string = nsg.id
