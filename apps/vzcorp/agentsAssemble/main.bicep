targetScope = 'subscription'


module workspace 'br/public:avm/res/operational-insights/workspace:0.12.0' = {
 scope: resourceGroup('vzcorp-agents-rg') 
  name: 'workspaceDeployment'
  params: {
    // Required parameters
    name: 'oiwmin001'
    // Non-required parameters
    location: 'westeurope'
    enableTelemetry: false
  }
}
