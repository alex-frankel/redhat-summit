@description('Location for all resources')
param location string = resourceGroup().location

@description('Name for the Virtual Machine.')
param vmName string

@description('Linux VM user account name')
param adminUsername string

@description('Type of authentication to use on the Virtual Machine')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Password or SSH key for the Virtual Machine')
@secure()
param adminPasswordOrSSHKey string

@description('The size of the Virtual Machine')
param vmSize string = 'Standard_B1ms'

@description('Capture serial console outputs and screenshots of the virtual machine running on a host to help diagnose startup issues')
@allowed([
  'off'
  'on'
])
param bootDiagnostics string = 'on'

@description('Determines whether or not a new storage account should be provisioned.')
param storageNewOrExisting string = 'new'

@description('Name of the storage account')
param storageAccountName string = 'storage${uniqueString(resourceGroup().id)}'

@description('Storage account type')
param storageAccountType string = 'Standard_LRS'

@description('Storage account kind')
param storageAccountKind string = 'Storage'

@description('Determines whether or not a new virtual network should be provisioned.')
param virtualNetworkNewOrExisting string = 'new'

@description('Name of the resource group for the existing virtual network')
param virtualNetworkResourceGroupName string = resourceGroup().name

@description('Name of the virtual network')
param virtualNetworkName string = 'VirtualNetwork'

@description('Address prefix of the virtual network')
param addressPrefixes array = [
  '10.0.0.0/16'
]

@description('Name of the subnet')
param subnetName string = 'default'

@description('Subnet prefix of the virtual network')
param subnetPrefix string = '10.0.0.0/24'

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

var nicName = '${uniqueString(resourceGroup().id)}-nic'
var networkSecurityGroupName_var = 'jbosseap-nsg'
var bootDiagnosticsCheck = ((storageNewOrExisting == 'new') && (bootDiagnostics == 'on'))
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

resource stg 'Microsoft.Storage/storageAccounts@2019-06-01' = if (bootDiagnosticsCheck) {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: storageAccountKind
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: networkSecurityGroupName_var
  location: location
}

resource vnet 'Microsoft.Network/virtualNetworks@2019-11-01' = if (virtualNetworkNewOrExisting == 'new') {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }

  // second declaration is only for referencing later on
  resource declaredSubnet 'subnets' existing = {
    name: subnetName
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: 'pip-for-${vmName}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    publicIPAddressVersion: 'IPv4'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2019-11-01' = {
  name: nicName
  location: location
  properties: {
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            // this is very ugly...
            id: virtualNetworkNewOrExisting == 'new' ? vnet::declaredSubnet.id : resourceId(virtualNetworkResourceGroupName, vnet::declaredSubnet.type, virtualNetworkName, subnetName)
          }
          publicIPAddress: {
            id: pip.id
          }
        }
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
          id: nic.id
        }
      ]
    }
    // todo - check if the endpoint can be dynamic
    diagnosticsProfile: ((bootDiagnostics == 'on') ? json('{"bootDiagnostics": {"enabled": true,"storageUri": "https://${storageAccountName}.blob.core.windows.net"}}') : json('{"bootDiagnostics": {"enabled": false}}'))
  }
  dependsOn: [
    nsg
  ]
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
      // todo - still in progress, but seems to work?!
      commandToExecute: 'echo \'${loadFileAsBase64('scripts/jbosseap-setup-redhat.sh')}\' | base64 -d > decodedScript.sh && chmod +x ./decodedScript.sh && ./decodedScript.sh \'${jbossEAPUserName}\' \'${jbossEAPPassword}\' \'${rhsmUserName}\' \'${rhsmPassword}\' \'${rhsmPoolEAP}\''
    }
  }
}

