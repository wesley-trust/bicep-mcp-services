@description('Name of the Storage Account that the Function App uses for host storage and deployment packages.')
param storageAccountName string

@description('Name of the Application Insights component used for telemetry.')
param applicationInsightsName string

@description('Principal ID for the Function App system-assigned managed identity.')
param managedIdentityPrincipalId string

@description('Optional user principal ID that requires access for testing or operational support.')
param userPrincipalId string = ''

@description('Enables role assignments for the optional user principal.')
param allowUserPrincipal bool = false

var roleDefinitions = {
  storageBlobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  storageQueueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  storageTableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  monitoringMetricsPublisher: '3913510d-42f4-4e42-8a64-420c390055eb'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' existing = {
  name: storageAccountName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

module storageBlobAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = if (!empty(managedIdentityPrincipalId)) {
  name: 'fn-storage-blob-${uniqueString(storageAccount.id, managedIdentityPrincipalId)}'
  params: {
    resourceId: storageAccount.id
    roleDefinitionId: roleDefinitions.storageBlobDataOwner
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Grant Storage Blob Data Owner to Function App managed identity.'
    roleName: 'Storage Blob Data Owner'
  }
}

module storageBlobAssignmentUser 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = if (allowUserPrincipal && !empty(userPrincipalId)) {
  name: 'fn-storage-blob-user-${uniqueString(storageAccount.id, userPrincipalId)}'
  params: {
    resourceId: storageAccount.id
    roleDefinitionId: roleDefinitions.storageBlobDataOwner
    principalId: userPrincipalId
    principalType: 'User'
    description: 'Grant Storage Blob Data Owner to user principal for testing.'
    roleName: 'Storage Blob Data Owner'
  }
}

module storageQueueAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = if (!empty(managedIdentityPrincipalId)) {
  name: 'fn-storage-queue-${uniqueString(storageAccount.id, managedIdentityPrincipalId)}'
  params: {
    resourceId: storageAccount.id
    roleDefinitionId: roleDefinitions.storageQueueDataContributor
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Grant Storage Queue Data Contributor to Function App managed identity.'
    roleName: 'Storage Queue Data Contributor'
  }
}

module storageQueueAssignmentUser 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = if (allowUserPrincipal && !empty(userPrincipalId)) {
  name: 'fn-storage-queue-user-${uniqueString(storageAccount.id, userPrincipalId)}'
  params: {
    resourceId: storageAccount.id
    roleDefinitionId: roleDefinitions.storageQueueDataContributor
    principalId: userPrincipalId
    principalType: 'User'
    description: 'Grant Storage Queue Data Contributor to user principal for testing.'
    roleName: 'Storage Queue Data Contributor'
  }
}

module storageTableAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = if (!empty(managedIdentityPrincipalId)) {
  name: 'fn-storage-table-${uniqueString(storageAccount.id, managedIdentityPrincipalId)}'
  params: {
    resourceId: storageAccount.id
    roleDefinitionId: roleDefinitions.storageTableDataContributor
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Grant Storage Table Data Contributor to Function App managed identity.'
    roleName: 'Storage Table Data Contributor'
  }
}

module storageTableAssignmentUser 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = if (allowUserPrincipal && !empty(userPrincipalId)) {
  name: 'fn-storage-table-user-${uniqueString(storageAccount.id, userPrincipalId)}'
  params: {
    resourceId: storageAccount.id
    roleDefinitionId: roleDefinitions.storageTableDataContributor
    principalId: userPrincipalId
    principalType: 'User'
    description: 'Grant Storage Table Data Contributor to user principal for testing.'
    roleName: 'Storage Table Data Contributor'
  }
}

module appInsightsAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = if (!empty(managedIdentityPrincipalId)) {
  name: 'fn-appinsights-${uniqueString(appInsights.id, managedIdentityPrincipalId)}'
  params: {
    resourceId: appInsights.id
    roleDefinitionId: roleDefinitions.monitoringMetricsPublisher
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Grant Monitoring Metrics Publisher to Function App managed identity.'
    roleName: 'Monitoring Metrics Publisher'
  }
}

module appInsightsAssignmentUser 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = if (allowUserPrincipal && !empty(userPrincipalId)) {
  name: 'fn-appinsights-user-${uniqueString(appInsights.id, userPrincipalId)}'
  params: {
    resourceId: appInsights.id
    roleDefinitionId: roleDefinitions.monitoringMetricsPublisher
    principalId: userPrincipalId
    principalType: 'User'
    description: 'Grant Monitoring Metrics Publisher to user principal for testing.'
    roleName: 'Monitoring Metrics Publisher'
  }
}
