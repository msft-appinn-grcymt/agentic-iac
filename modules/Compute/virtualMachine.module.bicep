param name string
param location string = resourceGroup().location
param tags object = {}
param vmSize string = 'Standard_DS2_v2'
param computerName string = name
param adminUsername string  = 'azureuser'
@secure()
param adminPassword string 
param sshPublicKey string = ''
param vmSubnet string
param OSPublisher string = 'Canonical'
param OSOffer string = 'UbuntuServer'
param OSSku string = '22_04-lts-gen2'
param OSVersion string = 'latest'
@allowed([
  'Linux'
  'Windows'
])
param OSType string = 'Linux'
@allowed([
  'PremiumV2_LRS'
  'Premium_LRS'
  'Premium_ZRS'
  'StandardSSD_LRS'
  'StandardSSD_ZRS'
  'Standard_LRS'
  'UltraSSD_LRS'
])
param OSDiskType string = 'StandardSSD_ZRS'
param OSDiskSizeGB int = 128
@allowed([
  'Delete'
  'Detach'
])
param OSDiskDeleteOption string = 'Delete'
@allowed([
  'password'
  'sshKey'
])
param authType string = 'password'
param bootDiagStorageUri string
param recoveryServicesVault string

// //Object with VMs network properties.
// //Configured as needed if public or private is set for the VM
// var vmNicProperties = isPublic ? {
//   privateIPAllocationMethod: 'Dynamic'
//   subnet:{
//     id: vmSubnet
//   }
//   publicIPAddress:{
//     id: VMpublicIpAddress.outputs.publicIpAddressId
//   }
// }: {
//   privateIPAllocationMethod: 'Dynamic'
//   subnet:{
//     id: vmSubnet
//   }
// }

// //Create the NSG to be attached to the VM's NIC
// //Options to define if HTTP,HTTPS and SSH inbound or HTTPS outbound access is allowed
// module VMNetworkSecurityGroup 'networkSecurityGroups.module.bicep' = {
//   name: '${name}NetworkSecurityGroup'
//   params:{
//     name: '${name}-nsg'
//     location: location
//     allowHttpInbound: nsgAllowHttpInbound
//     allowHttpsInbound: nsgAllowHttpsInbound
//     allowHttpsOutbound: nsgAllowHttpsOutbound
//     allowSsh: nsgAllowSsh
//     tags: tags
//   } 
// }

// //Create a public ip to attach to the VM
// module VMpublicIpAddress 'publicIp.module.bicep' = if (isPublic) {
//   name: '${name}publicIpAddress'
//   params:{
//     name: '${name}-pip'
//     location: location
//     sku: vmIpSKU
//     publicIPAllocationMethod: 'Dynamic'
//     tags: tags
//   }
// }

//Create the VMs Network Interface Card and configure the NSG and IP properties
resource virtualMachineNIC 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${name}-nic'
  location: location
  properties:{
    ipConfigurations:[
      {
        name: 'ipconfig-main'
        properties:  {
          privateIPAllocationMethod: 'Dynamic'
        subnet:{
          id: vmSubnet
          }
        } 
      }   
    ]
    // networkSecurityGroup:{
    //   id: VMNetworkSecurityGroup.outputs.nsgId
    // }
  }
  tags: tags
}

//Set OS profile options based on the authentication type
//Password or SSH Keys

var OSVMprofile = (authType == 'password') ? {
  computerName: computerName
  adminUsername: adminUsername
  //When Password is used
  adminPassword: adminPassword
} : {
    computerName: computerName
    adminUsername: adminUsername
    //When SSH Keys are used
    linuxConfiguration:{
      ssh:{
        publicKeys:[
          {
            keyData: sshPublicKey
            path: '/home/${adminUsername}/.ssh/authorized_keys'
          }
        ]
      }
    }  
}

//Create the VM using the previously created NIC and the OSVMprofile object
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: name
  location: location
  properties:{
    hardwareProfile:{
      vmSize: vmSize
    }
    osProfile: OSVMprofile
    storageProfile:{
      imageReference:{
        publisher: OSPublisher
        offer: OSOffer
        sku: OSSku
        version: OSVersion
      }
      osDisk: {
        osType: OSType
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: OSDiskType
        }
        deleteOption: OSDiskDeleteOption
        diskSizeGB: OSDiskSizeGB
      }
    }
    networkProfile:{
       networkInterfaces:[
        {
          id: virtualMachineNIC.id
          properties:{
            deleteOption: 'Delete'
          }
        }
       ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: bootDiagStorageUri
      }
    }    
  }
  tags: tags
}

// Add the virtual machines as protected items on recovery services vault

resource recoveryServiceVault 'Microsoft.RecoveryServices/vaults@2023-01-01' existing = {
  name: recoveryServicesVault
}

resource vaultName_backupFabric_protectionContainer_protectedItem 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2023-01-01' = {
  name: '${recoveryServiceVault.name}/Azure/iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${virtualMachine.name}/vm;iaasvmcontainerv2;${resourceGroup().name};${virtualMachine.name}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    policyId: '${recoveryServiceVault.id}/backupPolicies/DefaultPolicy'
    sourceResourceId: virtualMachine.id
  }
}





// //DevOps Agent install script and setup
// //Run the bash script to intall the Azure DevOps Agent and register it with the DevOps Organization
// resource devOpsAgentInstallScript 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = if (installDevOpsAgent) {
//   name: '${virtualMachine.name}/${virtualMachine.name}-devopsinstall'
//   location: location
//   properties:{
//     publisher: 'Microsoft.Azure.Extensions'
//     type: 'CustomScript'
//     typeHandlerVersion: '2.0'
//     autoUpgradeMinorVersion: true
//     settings:{
//       skipDos2Unix: false
//     }
//     protectedSettings:{
//       //base64 bash script that performs agent installation and configuration
//       //based on agentinstall.sh
//       //ideally would be created by pipeline on previous step passing the environment variables as secure parameters (PAT is included)
//       //and generated string would be passed as secure input through pipeline
//       script: devOpsAgentScript
//     }
//   }
//   tags: tags
// }

output VMId string = virtualMachine.id
