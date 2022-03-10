targetScope = 'subscription'


@maxLength(13)
@minLength(2)
param prefix string
param tfstate_rg_name string = '${prefix}-terraformstate-rg'
@allowed([
  'australiaeast'
])
param location string

resource rg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: tfstate_rg_name
  location: location
}

// Deploying storage account using module
module stg './tfstate-storage.bicep' = {
  name: 'storageDeployment'
  scope: resourceGroup(rg.name)
  params: {
    storageAccountName: '${prefix}statetf${take(uniqueString(prefix), 4)}'
    location: location
  }
}


output storageAccountName string = stg.outputs.storageAccountName
output containerName string = stg.outputs.containerName
output resourceGroupName string = rg.name
output storageAccessKey string = stg.outputs.storageAccountAccessKey
