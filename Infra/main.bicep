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

// Storage Account Parameters
param storageAccountName string = 'sa${customerName}${environmentName}${locationShortCode}'


// Storage Account Resource Group
param rgStorage string = 'rg-storage-${customerName}-${environmentName}-${locationShortCode}'
param rgWorkload string = 'rg-workload-${customerName}-${environmentName}-${locationShortCode}'
param rgMonitoring string = 'rg-monitoring-${customerName}-${environmentName}-${locationShortCode}'


// Log Analytics Parameteres
param skuNameLogAnalytics string = 'PerGB2018'

@description('Log Analytics Daily Quota in GB. Default: 1GB')
param dailyQuotaGb int = 1

@description('Number of days data will be retained for.')
param dataRetention int = 365

// *********************** No Hardcoded Values below this point ********************************************** // 


/*
// Resource Group
*/
@description('Array of resource Groups.')
param resourceGroupArray array = [
  {
    name: rgWorkload
    location: location
  }
  {
    name: rgStorage
    location: location
  }
  {
    name: rgMonitoring
    location: location
  }
]

//MARK: CreateResourceGroups
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

//MARK: StorageAccount- 
@description('Deploy storage account')
module createStorageAccount 'modules/storage/storage-account/main.bicep' = {
  scope: resourceGroup(rgStorage)
  name: storageAccountName
  params: {
    name: storageAccountName
    location: location
    tags: tags
    diagnosticSettings: [
      {
        workspaceResourceId: createAzureLogAnalytics.outputs.resourceId // This is the resourceId of the Log Analytics workspace
      }
    ]
  }
  dependsOn: [
    createResourceGroups
  ]
}

//MARK: AzureLogAnalytics
 @description('Deploy Azure Log Analytics')
 module createAzureLogAnalytics 'modules/operational-insights/workspace/main.bicep' = {
   scope: resourceGroup(rgMonitoring)
   name: 'logAnalytics'
   params: {
     name: 'la-${customerName}-${environmentName}-${locationShortCode}'
     skuName: skuNameLogAnalytics
     location: location
     dailyQuotaGb: dailyQuotaGb
     dataRetention: dataRetention
     tags: tags
   }
   dependsOn: [
    createResourceGroups
   ]
 }
