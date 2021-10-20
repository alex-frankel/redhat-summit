param location string = resourceGroup().location
param vmName string

@description('Type of authentication to use on the Virtual Machine')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Linux VM user account name')
param adminUsername string

@description('User name for JBoss EAP Manager')
param jbossEAPUserName string

@description('Password for JBoss EAP Manager')
@secure()
param jbossEAPPassword string

@description('User name for Red Hat subscription Manager')
param rhsmUserName string

@description('Password for Red Hat subscription Manager')
@secure()
param rhsmPassword string

@description('Red Hat Subscription Manager Pool ID (Should have EAP entitlement)')
@minLength(32)
@maxLength(32)
param rhsmPoolEAP string

@description('Password or SSH key for the Virtual Machine')
@secure()
param adminPasswordOrSSHKey string

@description('The size of the Virtual Machine')
param vmSize string = 'Standard_B1ms'

param nicId string

var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrSSHKey
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2019-12-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrSSHKey
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : linuxConfiguration) // todo - check if "null" is allowed
    }
    storageProfile: {
      imageReference: {
        publisher: 'RedHat'
        offer: 'RHEL'
        sku: '8_3'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}_OSDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicId
        }
      ]
    }
  }
}

resource jboss_setup 'Microsoft.Compute/virtualMachines/extensions@2021-04-01' = {
  parent: vm

  name: 'jbosseap-setup-extension'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'echo \'${loadFileAsBase64('../scripts/jbosseap-setup-redhat.sh')}\' | base64 -d > decodedScript.sh && chmod +x ./decodedScript.sh && ./decodedScript.sh \'${jbossEAPUserName}\' \'${jbossEAPPassword}\' \'${rhsmUserName}\' \'${rhsmPassword}\' \'${rhsmPoolEAP}\''
    }
  }
}

// && echo \'${loadFileAsBase64('../scripts/JBoss-EAP_on_Azure.war')}\' | base64 -d > decodedWar.sh 
