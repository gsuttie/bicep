@description('Location for all resources.')
param location string

@description('Tags of the resource.')
param tags object = {}

param afdWAFPolicyName string

@allowed([
  '2.0'
  '1.1'
])
param defaultManagedRuleSetVersion string = '2.0'

@allowed([
  'Microsoft_DefaultRuleSet'
])
param defaultManagedRuleSetType string = 'Microsoft_DefaultRuleSet'

@allowed([
  '1.0'
])
param additionalManagedRuleSetVersion string = '1.0'

@allowed([
  'Block'
  'Log'
  'Redirect'
  ''
])
param defaultManagedRuleSetAction string = 'Block'

@allowed([
  'Microsoft_BotManagerRuleSet'
])
param additionalManagedRuleSetType string = 'Microsoft_BotManagerRuleSet'

@allowed([
  'Detection'
  'Prevention'
])
param wafPolicyMode string = 'Detection'

@allowed([
  'Disabled'
  'Enabled'
])
param wafRequestBodyCheck string = 'Enabled'

@allowed([
  'Premium_AzureFrontDoor'
  'Standard_AzureFrontDoor'
  'Classic_AzureFrontDoor'
])
param afdWAFSKU string = 'Premium_AzureFrontDoor'


resource afdWAFPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2020-11-01' = {
  name: afdWAFPolicyName
  location: location
  tags: tags
  sku: {
    name: afdWAFSKU
  }
  properties: {
    managedRules:{
      managedRuleSets:[
        {
          ruleSetVersion: defaultManagedRuleSetVersion
          ruleSetType: defaultManagedRuleSetType
          ruleSetAction: !empty(defaultManagedRuleSetAction) ? defaultManagedRuleSetAction : null
        }
        {
          ruleSetVersion: additionalManagedRuleSetVersion
          ruleSetType: additionalManagedRuleSetType
        }
      ]
    }
    policySettings: {
      mode: wafPolicyMode
      requestBodyCheck: wafRequestBodyCheck
    }
  }
}

output resourceId string = afdWAFPolicy.id
