param name string
param location string = resourceGroup().location
param tags object = {}
@description('The SKU Tier of the cluster')
@allowed([
  'Free'
  'Standard'
  'Premium'
])
param tier string = 'Standard'
@description('Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize.')
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0
@description('Use availability zones or not in the node pools. Only if region supports availability zones.')
param azRedundant bool = true
@description('The default number of nodes for the system pool.')
@minValue(1)
@maxValue(3)
param systemPoolNodeCount int = 3
@description('Minimum number of instances for the system pool')
@minValue(1)
@maxValue(3)
param systemPoolMinNodeCount int = 3
@description('Maximum number of instances for the system pool')
@minValue(3)
@maxValue(10)
param systemPoolMaxNodeCount int = 6
@description('The size of the Virtual Machine for the system pool.')
param systemPoolNodeSize string = 'standard_d4s_v5'
@description('The default number of nodes for the application pool.')
@minValue(1)
@maxValue(50)
param applicationPoolNodeCount int = 3
@description('Minimum number of instances for the application pool')
@minValue(1)
@maxValue(3)
param applicationPoolMinNodeCount int = 1
@description('Maximum number of instances for the applicatiob pool')
@minValue(3)
@maxValue(20)
param applicationPoolMaxNodeCount int = 20
@description('The size of the Virtual Machine for the application pool.')
param applicationPoolNodeSize string = 'standard_d4s_v5'
@description('Maximun number of pods for the application pool')
param applicationPoolMaxPods int = 110
@description('Use Azure Linux Container Host OS')
param azureLinuxOS bool = true
@description('Subnet for the system pool - only for Azure CNI')
param systemPoolSubnetId string
@description('Subnet for the application pool - only for Azure CNI')
param applicationPoolSubnetId string
@description('Whether to enable private cluster')
param enablePrivateCluster bool = true
@description('Channel to use for managing Kubernetes version upgrades. Default is set to none')
param upgradeChannel string = 'none'
@description('Manner in which the node image is upgraded. Default is set to none')
param nodeOSUpgradeChannel string = 'None'
@description('Network interface to use')
@allowed([
  'azure'
  'kubenet'
  'none'
])
param networkPlugin string = 'azure'
@description('Use Azure CNI Overalay Network')
param useAzureCNIOverlay bool = true
@description('Network policy mode to use')
@allowed([
  'calico'
  'azure'
  'cilium'
])
param networkPolicy string = 'cilium'
@description('Use Cilium with Azure CNI flag')
param useCiliumWithAzureCNI bool = true
@description('Outbound type to use for egress traffic')
@allowed([
  'loadBalancer'
  'userDefinedRouting'
  'managedNATGateway'
  'userAssignedNATGateway'
])
param outboundType string = 'loadBalancer'
@description('A CIDR notation IP range from which to assign service cluster IPs. It must not overlap with any Subnet IP ranges.')
param serviceCidr string
@description('A CIDR notation IP range from which to assign pod IPs when kubenet is used.')
param podCidr string
@description('Enable Key Vault CSI driver')
param keyVaultCSI bool = true


resource aks 'Microsoft.ContainerService/managedClusters@2023-07-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku:{
    name: 'Base'
    tier: tier
  }
  properties: {
    dnsPrefix: 'privatedns-${name}'
    // aadProfile: {
    //   managed: enabledManagedAAD
    //   enableAzureRBAC: enableAzureRBAC
    // }
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
    }
    autoUpgradeProfile: {
      upgradeChannel: upgradeChannel
      nodeOSUpgradeChannel: nodeOSUpgradeChannel
    }
    agentPoolProfiles: [
      {
        name: 'systempool'
        availabilityZones: azRedundant ? pickZones('Microsoft.Compute', 'virtualMachines',location) : []
        enableAutoScaling: true
        osDiskSizeGB: osDiskSizeGB
        minCount: systemPoolMinNodeCount
        maxCount: systemPoolMaxNodeCount
        count: systemPoolNodeCount
        vmSize: systemPoolNodeSize
        osType: azureLinuxOS ? 'AzureLinux' : 'Ubuntu'
        mode: 'System'
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        vnetSubnetID: systemPoolSubnetId
        tags: tags
      }
      {
        name: 'apppool'
        availabilityZones: azRedundant ? pickZones('Microsoft.Compute', 'virtualMachines',location) : []
        enableAutoScaling: true
        osDiskSizeGB: osDiskSizeGB
        minCount: applicationPoolMinNodeCount
        maxCount: applicationPoolMaxNodeCount
        count: applicationPoolNodeCount
        vmSize: applicationPoolNodeSize
        maxPods: applicationPoolMaxPods
        osType: azureLinuxOS ? 'AzureLinux' : 'Ubuntu'
        mode: 'User'
        nodeLabels: {
          poolType: 'application'
        }
        vnetSubnetID: applicationPoolSubnetId
        tags: tags
      }
    ]
    networkProfile: networkPlugin == 'azure' && useAzureCNIOverlay ? useCiliumWithAzureCNI ? {
      loadBalancerSku: 'Standard'
      networkPlugin: networkPlugin
      networkPluginMode: 'overlay'
      networkPolicy: networkPolicy
      networkDataplane: 'cilium' 
      outboundType: outboundType
      serviceCidr: serviceCidr
      dnsServiceIP: '172.17.34.10'
      podCidr: podCidr
    } : {
      loadBalancerSku: 'Standard'
      networkPlugin: networkPlugin
      networkPluginMode: 'overlay'
      networkPolicy: networkPolicy
      networkDataplane: 'azure' 
      outboundType: outboundType
      serviceCidr: serviceCidr
      dnsServiceIP: '172.17.34.10'
      podCidr: podCidr
    }: {
      loadBalancerSku: 'Standard'
      networkPlugin: networkPlugin
      networkPolicy: networkPolicy
      outboundType: outboundType
      serviceCidr: serviceCidr
      podCidr: podCidr
      dnsServiceIP: '172.17.34.10'
    }
    addonProfiles: {
      azureKeyVaultSecretsProvider: {
        enabled: keyVaultCSI
        config: {
          enableSecretRotation: 'true'
        }
      }
    }
  }  
}
