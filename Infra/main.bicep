// This file operates at subscription level.
// This is a modular deployment. This file, 'main.bicep', will call bicep modules within the /modules directory.
// The only resources that will be directly deployed by this file will be the resource groups.

// This file can only be deployed at a subscription scope
targetScope = 'subscription'

@description('Subscription ID passed in from PowerShell script')
param subscriptionId string = ''

@description('Logged in user details. Passed in from ent "deployNow.ps1" script.')
param updatedBy string = ''

@description('Environment Type: Test, Acceptance/UAT, Production, etc. Passed in from ent "deployNow.ps1" script.')
@allowed([
  'test'
  'dev'
  'prod'
])
param environmentName string = 'test'

@description('The customer name.')
param customerName string

@description('Azure Region to deploy the resources in.')
@allowed([
  'westeurope'
  'northeurope'
  'uksouth'
  'ukwest'
])
param location string = 'westeurope'

@description('Location shortcode. Used for end of resource names.')
param locationShortCode string

@description('Add tags as required as Name:Value')
param tags object = {
  Environment: environmentName
  Customer: customerName
  LastUpdatedOn: utcNow('d')
  LastDeployedBy: updatedBy
  Owner: updatedBy
  Product: ''
  CostCenter: ''
  Deployedby: ''
}


// *********************** No Hardcoded Values below this point ********************************************** // 


/*
// Resource Group
*/
@description('Array of resource Groups.')
param resourceGroupArray array = [
  {
    name: 'rg-${customerName}-workload-${environmentName}-${locationShortCode}' //0
    location: location
  }
]

// Deploy required Resource Groups - New Resources 
module createResourceGroups 'modules/resources/resource-group/main.bicep' = [
  for (resourceGroup, i) in resourceGroupArray: {
    scope: subscription(subscriptionId)
    name: 'rg-${i}-${customerName}-${environmentName}-${locationShortCode}'
    params: {
      name: resourceGroup.name
      location: resourceGroup.location
      tags: tags
    }
  }
]
