param vnetName string
param location string = resourceGroup().location
param tags object = {}
param vnetAddressPrefix array
param subnetConfigs array
param ddosProtectionPlanId string?

var minName = split(vnetName, '-')[0]
var rgName = split(vnetName, '-')[1]
var subnetNamePrefix = '${minName}-${rgName}-Snet'
var nsgNamePrefix = '${minName}-${rgName}-NSG'

/// Determines if a network security group (NSG) is required based on the subnet configuration.
///
/// @param subnetConfig - The subnet configuration object.
/// @returns - True if an NSG is required, false otherwise.
func requiresNsg(subnetConfig object) bool => subnetConfig.usage == 'VM/PrivateEndpoint' || subnetConfig.usage == 'VM'

/**
 * This function takes an array of subnet configurations and an index,
 * and returns a string representing the sequence suffix for the subnet.
 * The sequence suffix is calculated based on the number of subnets in the
 * array that have a non-reserved naming convetion.
 *
 * @param configs - An array of subnet configurations.
 * @param idx - The index of the subnet configuration to calculate the sequence suffix for.
 * @returns A string representing the sequence suffix for the subnet.
 */
func getSubnetSequenceSuffix(configs array, idx int) string =>  padLeft(length(filter(take(configs,idx+1),subnet => (subnet.usage != 'Bastion' && subnet.usage != 'AppGateway' && subnet.usage != 'VpnGateway'))),2,'0')

var subnetConfigsWithIndex = map(range(0, length(subnetConfigs)), index => union(subnetConfigs[index], { 
  index: index
  name: subnetConfigs[index].usage == 'Bastion' ? 'AzureBastionSubnet' 
      : subnetConfigs[index].usage == 'AppGateway' ? '${minName}-${rgName}-AppGW-Snet'
      : subnetConfigs[index].usage == 'VpnGateway' ? 'GatewaySubnet'
      : subnetConfigs[index].usage == 'Postgres' ? '${minName}-${rgName}-PostgresSnet'
      :'${subnetNamePrefix}${getSubnetSequenceSuffix(subnetConfigs, index)}'
}))

var privateEndpointSubnetConfig = first(filter(subnetConfigsWithIndex, subnet => subnet.usage == 'VM/PrivateEndpoint'))
var appGatewaySubnetConfig = first(filter(subnetConfigsWithIndex, subnet => subnet.usage == 'AppGateway'))
var bastionSubnetConfig = first(filter(subnetConfigsWithIndex, subnet => subnet.usage == 'Bastion'))
var appServiceSubnetConfigs = filter(subnetConfigsWithIndex, subnet => subnet.usage == 'AppService')
var mySQLSubnetConfigs = filter(subnetConfigsWithIndex, subnet => subnet.usage == 'mySQL')
var postgreSQLSubnetConfigs = filter(subnetConfigsWithIndex, subnet => subnet.usage == 'Postgres')
var vpnGatewaySubnetConfig = first(filter(subnetConfigsWithIndex, subnet => subnet.usage == 'VpnGateway'))
var aksSubnetConfigs = filter(subnetConfigsWithIndex, subnet => subnet.usage == 'AKS')


//  Define the array of subnets based on the provided subnet configurations.
var subnets = [for (subnet, index) in subnetConfigsWithIndex: {
  name: subnet.name
  properties: {
    addressPrefix: subnet.addressPrefix
    privateEndpointNetworkPolicies: subnet.usage == 'VM/PrivateEndpoint' ? 'Disabled' : 'Enabled'
    delegations: subnet.usage == 'AppService' ? [ {
        name: 'delegation'
        properties: {
          serviceName: 'Microsoft.Web/serverfarms'
        }
      } ] : subnet.usage == 'mySQL' ? [ {
        name: 'delegation'
        properties: {
          serviceName: 'Microsoft.DBforMySQL/flexibleServers'
        }
      } ] : subnet.usage == 'Postgres' ? [ {
        name: 'delegation'
        properties: {
          serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
        }
      } ] : []
      }
}]

module vnet 'vnet.module.bicep' = {
  name: 'vnet-${vnetName}'
  params: {
    name: vnetName
    location: location
    tags: tags
    addressPrefix: vnetAddressPrefix
    subnets: subnets
    ddosProtectionPlanId: ddosProtectionPlanId
  }
}

// Create NSG(s) with only the default rules
// One NSG for each Non delegated subnet - will be assigned post bicep deployment through the bash script
var nsgSubnets = [for (subnet, index) in filter(subnetConfigsWithIndex, subnet => requiresNsg(subnet)): {
  subNetName: subnet.name
  nsgName: '${nsgNamePrefix}${padLeft(index + 1, 2, '0')}'
}]

// Create NSG(s) with only the default rules
// One NSG for each Non delegated subnet - will be assigned post bicep deployment through the bash script
module nsgs './networksecuritygroup.module.bicep' = [for (nsg, i) in nsgSubnets: {
  name: nsg.nsgName
  params: {
    name: nsg.nsgName
    location: location
    tags: tags
  }
}]

output vnetId string = vnet.outputs.vnetId
output vnetName string = vnet.outputs.vnetName
output subnets array = vnet.outputs.subnets
output delegations array = vnet.outputs.delegations

output appGatewaySubnetId string = appGatewaySubnetConfig != null ? vnet.outputs.subnets[appGatewaySubnetConfig!.index].id : ''
output bastionSubnetId string = bastionSubnetConfig != null ? vnet.outputs.subnets[bastionSubnetConfig!.index].id : ''
output privateEndpointSubnetId string = privateEndpointSubnetConfig != null ? vnet.outputs.subnets[privateEndpointSubnetConfig!.index].id : ''
output appServiceSubnetIds array = [for (subnet, i) in appServiceSubnetConfigs: vnet.outputs.subnets[subnet.index].id]
output mySQLSubnetIds array = [for (subnet, i) in mySQLSubnetConfigs: vnet.outputs.subnets[subnet.index].id]
output postgreSQLSubnetIds array = [for (subnet, i) in postgreSQLSubnetConfigs: vnet.outputs.subnets[subnet.index].id]
output vpnGatewaySubnetId string = vpnGatewaySubnetConfig != null ? vnet.outputs.subnets[vpnGatewaySubnetConfig!.index].id : ''
output AKSSubnetIds array = [for (subnet, i) in aksSubnetConfigs: vnet.outputs.subnets[subnet.index].id]


//output aksSubnetId string = aksSubnetConfig != null ? vnet.outputs.subnets[aksSubnetConfig!.index].id : ''

output nsgs array =[for (nsg, i) in nsgSubnets: nsgs[i]]
output nsgSubnets array = nsgSubnets

output usages array = [for (subnet, i) in subnetConfigs: {
  id: vnet.outputs.subnets[i].id
  name: vnet.outputs.subnets[i].name
  usage: subnetConfigs[i].usage
}]


