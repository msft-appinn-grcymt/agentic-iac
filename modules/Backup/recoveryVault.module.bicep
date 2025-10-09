param location string
param name string
param tags object = {}
param skuName string = 'RS0'
param skuTier string = 'Standard'
param publicNetworkAccess string = 'Enabled'
param timeNow string = utcNow('yyyy-MM-dd')

resource recoveryVault 'Microsoft.RecoveryServices/vaults@2023-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    publicNetworkAccess: publicNetworkAccess
  }
}

// Set up vault LRS storage

resource vaultBackupStorageConfig 'Microsoft.RecoveryServices/vaults/backupstorageconfig@2023-01-01' = {
  name: 'vaultstorageconfig'
  location: location
  tags: tags
  parent: recoveryVault
  properties: {
    //storageModelType: 'LocallyRedundant'
    storageModelType: 'GeoRedundant'
    crossRegionRestoreFlag: false
  }
}

// Default VM backup policy
resource defaultPolicyVM 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-01-01' = {
  name: 'DefaultPolicy'
  location: location
  tags: tags
  parent: recoveryVault
  properties: {
    backupManagementType: 'AzureIaasVM'
    instantRpRetentionRangeInDays: 2
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '${timeNow}T01:30:00Z'
        ]
        retentionDuration: {
          count: 30
          durationType: 'Days'
        }
      }
    }
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '${timeNow}T01:30:00Z'
      ]
      scheduleWeeklyFrequency: 0
    }
    tieringPolicy: {
      ArchivedRP: {
        tieringMode: 'DoNotTier'
        duration: 0
        durationType: 'Invalid'
      }
    }
    timeZone: 'GTB Standard Time'
  }
}



//Enhanced Backup Policy
resource enhancedPolicyVM 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-01-01' = {
  name: 'EnhancedPolicy'
  location: location
  tags: tags
  parent: recoveryVault
  properties: {
    backupManagementType: 'AzureIaasVM'
    instantRpRetentionRangeInDays: 2
    policyType: 'V2'
    timeZone: 'GTB Standard Time'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicyV2'
      scheduleRunFrequency: 'Daily'
      dailySchedule : {
        scheduleRunTimes: [
          '${timeNow}T01:30:00Z'
        ]
      }
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '${timeNow}T01:30:00Z'
        ]
        retentionDuration: {
          count: 30
          durationType: 'Days'
        }
      }
    }
    tieringPolicy: {
      ArchivedRP: {
        tieringMode: 'DoNotTier'
        duration: 0
        durationType: 'Invalid'
      }
    }
  }
}


output name string = recoveryVault.name
