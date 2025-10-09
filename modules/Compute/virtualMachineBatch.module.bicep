param vmBatchName string
param vmBatchCount int
param location string = resourceGroup().location
param tags object = {}
param vmSize string = 'Standard_DS2_v2'
param vmAdminUsername string
@secure()
param vmAdminPassword string
param vmSubnetId string
param vmOSpublisher string
param vmOSOffer string
param vmOSSku string
param vmOSVersion string
param vmOSType string
param vmOSDiskType string
param vmOSDiskSizeGB int
param vmOSDiskDeleteOption string
param bootDiagStorageAccount string
param recoveryServicesVault string
/// Create the virtual machines

module virtualMachine './virtualMachine.module.bicep' = [for i in range(0, vmBatchCount): {
  name: '${vmBatchName}-VM0${i + 1}'
  params: {
    name: '${vmBatchName}-VM0${i + 1}'
    location: location
    tags: tags
    vmSize: vmSize
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    vmSubnet: vmSubnetId
    OSPublisher: vmOSpublisher
    OSOffer: vmOSOffer
    OSSku: vmOSSku
    OSVersion: vmOSVersion
    OSType: vmOSType
    OSDiskType: vmOSDiskType
    OSDiskSizeGB: vmOSDiskSizeGB
    OSDiskDeleteOption: vmOSDiskDeleteOption
    bootDiagStorageUri: bootDiagStorageAccount
    recoveryServicesVault: recoveryServicesVault
  }
}]

