param name string
param location string
param tags object = {}
param retentionInDays int = 90
param skuName string = 'PerGB2018'

resource laWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  location: location
  name: name
  tags: tags
  properties: {
    retentionInDays: retentionInDays
    sku:{
      name: skuName
    }
  }
}

output workspaceId string = laWorkspace.id
