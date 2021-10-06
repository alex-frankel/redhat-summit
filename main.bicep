@description('Name for the Virtual Machine.')
param vmName string

@description('Linux VM user account name')
param adminUsername string

@description('Password or SSH key for the Virtual Machine')
@secure()
param adminPasswordOrSSHKey string

@description('Name of the resource group for the existing virtual network')
param virtualNetworkResourceGroupName string = resourceGroup().name

@description('Determines whether or not a new virtual network should be provisioned.')
param virtualNetworkNewOrExisting string = 'new'

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

module deployNetworking 'modules/networking.bicep' = {
  name: 'deployNetworking'
  params: {
    vmName: vmName
    virtualNetworkNewOrExisting: virtualNetworkNewOrExisting
    virtualNetworkResourceGroupName: virtualNetworkResourceGroupName
  }
}

module deployVm 'modules/vm.bicep' = {
  name: 'deployVm'
  params: {
    adminPasswordOrSSHKey: adminPasswordOrSSHKey
    adminUsername: adminUsername
    jbossEAPPassword: jbossEAPPassword
    jbossEAPUserName: jbossEAPUserName
    nicId: deployNetworking.outputs.nicId
    rhsmPassword: rhsmPassword
    rhsmPoolEAP: rhsmPoolEAP
    rhsmUserName: rhsmUserName
    vmName: vmName
  }
}
