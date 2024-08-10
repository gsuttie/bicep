// sqlserver-keyvault-encryption.bicep
param sqlServerName string
param keyVaultName string
param keyName string
param keyVersion string
param keyUri string
param autoRotationEnabled bool

resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' existing = {
  name: sqlServerName
}

// Create sql server key from key vault
resource sqlServerKey 'Microsoft.Sql/servers/keys@2022-05-01-preview' = {
  name: '${keyVaultName}_${keyName}_${keyVersion}'
  parent: sqlServer
  properties: {
    serverKeyType: 'AzureKeyVault'
    uri: keyUri
  }
}

// Create the encryption protector
resource propector 'Microsoft.Sql/servers/encryptionProtector@2022-05-01-preview' = {
  name: 'current'
  parent: sqlServer
  properties: {
    serverKeyType: 'AzureKeyVault'
    serverKeyName: sqlServerKey.name
    autoRotationEnabled: autoRotationEnabled
  }
}
