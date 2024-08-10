targetScope = 'tenant'

@description('Required. The group ID of the Management group')
param name string

@description('Optional. The friendly name of the management group. If no value is passed then this field will be set to the group ID.')
param displayName string = ''

@description('Optional. The management group parent name. Defaults to current scope.')
param parentName string = ''

@description('Optional. Array of subscription IDs to add to the management group.')
param subscriptionIds array = []

resource managementGroup 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: name
  properties: {
    displayName: displayName
    details: !empty(parentName) ? {
      parent: {
        id: tenantResourceId('Microsoft.Management/managementGroups', parentName)
      }
    } : null
  }
}

resource subscriptionParentManagementGroup 'Microsoft.Management/managementGroups/subscriptions@2021-04-01' = [for subscriptionId in subscriptionIds: {
  name: subscriptionId
  parent: managementGroup
  }]

@description('The name of the management group')
output name string = managementGroup.name

@description('The resource ID of the management group')
output resourceId string = managementGroup.id
