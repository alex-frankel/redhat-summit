param location string = resourceGroup().location

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

@description('Name for the Virtual Machine.')
param baseName string

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

resource nsg 'Microsoft.Network/networkSecurityGroups@2019-11-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'rdp'
        properties: {
          description: 'AllowRDP'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'webHttp'
        properties: {
          description: 'Allow WEB Http'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 101
          direction: 'Inbound'
        }
      }
      {
        name: 'ssh'
        properties: {
          description: 'Allow SSH'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '22'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 102
          direction: 'Inbound'
        }
      }
      {
        name: 'web8080'
        properties: {
          description: 'Allow WEB Http'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8080'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 103
          direction: 'Inbound'
        }
      }
      {
        name: 'web9990'
        properties: {
          description: 'Allow WEB Http'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '9990'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 104
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: 'pip-for-${baseName}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    publicIPAddressVersion: 'IPv4'
  }
}

var nicName = '${uniqueString(resourceGroup().id)}-nic'
var networkSecurityGroupName = 'jbosseap-nsg'

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

output nicId string = nic.id
