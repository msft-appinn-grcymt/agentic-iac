param name string
param location string = resourceGroup().location
param tags object = {}
param subnetId string
param dnsLabelPrefix string
// // param frontendWebAppFqdn string
// @description('SKU of the Application Gateway')
// @allowed([
//   'Standard_v2'
//   'WAF_v2'
// ])
// param skuName string = 'Standard_v2' 
@allowed([
  'Standard_v2'
  'WAF_v2'
])
@description('SKU of the Application Gateway')
param skuTier string = 'Standard_v2' 
@description('Minimum capacity (instances) of the Application Gateway')
param autoscaleMinCapacity int = 1
@description('Maximum capacity (instances) of the Application Gateway')
param autoscaleMaxCapacity int = 4

var minName = split(name,'-')[0]
var rgName = split(name,'-')[1]

var resourceNames = {
  publicIP: '${minName}-${rgName}-AppGW-pip'
  backendAddressPool: '${minName}-${rgName}-BckndPool'
  frontendPort80: 'feport-${name}-80'
  frontendPort443: 'feport-${name}-443'
  frontendIpConfiguration: 'feip-${name}'
  backendHttpSettingFor80: '${minName}-${rgName}-BcndSet'
  httpListener: 'httplstn-${name}'
  requestRoutingRule: 'rqrt-${name}'
}

module pip 'publicIp.module.bicep' = {
  name: resourceNames.publicIP
  params: {
    name: resourceNames.publicIP
    dnsLabelPrefix: dnsLabelPrefix
    location: location
    tags: tags
    skuName: 'Standard'
  }
}



// If WAF_v2 then create a standard firewall policy
resource firewallPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-03-01' = if (skuTier == 'WAF_v2') {
  name: '${minName}-${rgName}-WAF'
  location: location
  tags: tags
  properties: {
    customRules: []
    policySettings: {  requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Detection'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
      exclusions: []
    }
  }
}


resource applicationGateway 'Microsoft.Network/applicationGateways@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuTier
      tier: skuTier
    }
    autoscaleConfiguration: {
      minCapacity: autoscaleMinCapacity
      maxCapacity: autoscaleMaxCapacity
    }
    webApplicationFirewallConfiguration: skuTier == 'WAF_v2' ? {
      enabled: true
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
    } : null
    gatewayIPConfigurations: [
      {
        name: '${name}-ip-configuration'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: resourceNames.frontendIpConfiguration
        properties: {
          publicIPAddress: {
            id: pip.outputs.pipId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: resourceNames.frontendPort80
        properties: {
          port: 80
        }
      }
    ]
    probes: []
    backendAddressPools: [
      {
        name: resourceNames.backendAddressPool
        properties: {
          backendAddresses: []
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: resourceNames.backendHttpSettingFor80
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 120     
        }
      }
    ]
    httpListeners: [
      {
        name: resourceNames.httpListener
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, resourceNames.frontendIpConfiguration)
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, resourceNames.frontendPort80)
          }
          protocol: 'Http'
          sslCertificate: null
        }
      }
    ]
    requestRoutingRules: [
      {
        name: resourceNames.requestRoutingRule
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, resourceNames.httpListener)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, resourceNames.backendAddressPool)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, resourceNames.backendHttpSettingFor80)
          }
        }
      }
    ]
  }
}
