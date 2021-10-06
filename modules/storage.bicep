param location string = resourceGroup().location

@description('Name of the storage account')
param storageAccountName string = 'storage${uniqueString(resourceGroup().id)}'

@description('Storage account type')
param storageAccountType string = 'Standard_LRS'

@description('Storage account kind')
param storageAccountKind string = 'Storage'

resource stg 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: storageAccountKind
}

output storageAccountName string = storageAccountName
