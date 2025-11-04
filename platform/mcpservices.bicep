targetScope = 'resourceGroup'

// Common
@description('Azure region for the Function App resources. Defaults to the current resource group location.')
param location string = resourceGroup().location

@description('Optional tags applied to the resources.')
param tags object = {}
var normalisedTags = empty(tags) ? null : tags

// Service
@description('Flag to determine whether to deploy the service. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployServiceString string
var deployService = bool(deployServiceString)

// Virtual Network
param virtualNetworkName string
param virtualNetworkResourceGroupName string
param mcpSubnetName string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
}

resource mcpSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  name: mcpSubnetName
  parent: virtualNetwork
}

// Storage Account
@description('Flag to determine whether to deploy the Storage Account. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployStorageAccountString string
var deployStorageAccount = bool(deployStorageAccountString)

@description('Name of the Storage Account for the Function App.')
param storageAccountName string

@description('Blob container name used for deployment packages (zip deploy).')
param deploymentContainerName string

module storage 'br/public:avm/res/storage/storage-account:0.28.0' = if (deployService && deployStorageAccount) {
  name: 'storage'
  params: {
    name: storageAccountName
    location: location
    tags: normalisedTags
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    dnsEndpointType: 'Standard'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    minimumTlsVersion: 'TLS1_2'
    blobServices: {
      containers: [
        {
          name: deploymentContainerName
          publicAccess: 'None'
        }
      ]
    }
    queueServices: {}
    tableServices: {}
  }
}

// Hosting Plan
@description('Flag to determine whether to deploy the Hosting Plan. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployHostingPlanString string
var deployHostingPlan = bool(deployHostingPlanString)

@description('Name of the Azure Functions Flex Consumption plan to create.')
param hostingPlanName string

@description('Flag to enable zone redundancy on the Flex Consumption plan. Accepted values: "true", "false".')
param zoneRedundantString string = 'false'
var zoneRedundant = bool(zoneRedundantString)

module hostingPlan 'br/public:avm/res/web/serverfarm:0.5.0' = if (deployService && deployHostingPlan) {
  name: 'hostingplan'
  params: {
    name: hostingPlanName
    location: location
    tags: normalisedTags
    skuName: 'FC1'
    kind: 'functionapp'
    zoneRedundant: zoneRedundant
  }
}

// Function App
@description('Flag to determine whether to deploy the Function App. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployFunctionAppString string
var deployFunctionApp = bool(deployFunctionAppString)

@description('Name of the Function App to create.')
param mcpFunctionAppName string

@description('Maximum number of instances for the Function App scale controller.')
param maximumInstanceCountString string = '100'
var maximumInstanceCount = int(maximumInstanceCountString)

@description('Instance memory allocation in MB for Flex Consumption workers.')
param instanceMemoryMBString string = '2048'
var instanceMemoryMB = int(instanceMemoryMBString)

@description('Function App runtime stack.')
param mcpRuntime string = 'powerShell'

@description('Runtime version used by the Function App runtime stack.')
param mcpRuntimeVersion string = '7.4'

@description('Optional map of application settings to merge with the default set.')
param additionalAppSettings object = {}

var additionalAppSettingsArray = [
  for setting in items(additionalAppSettings): {
    name: setting.key
    value: setting.value
  }
]

module functionApp 'br/public:avm/res/web/site:0.19.0' = if (deployService && deployFunctionApp) {
  name: 'functionapp'
  params: {
    name: mcpFunctionAppName
    location: location
    tags: normalisedTags
    kind: 'functionapp,linux'
    serverFarmResourceId: hostingPlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    virtualNetworkSubnetResourceId: mcpSubnet.id
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.outputs.primaryBlobEndpoint}${deploymentContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: maximumInstanceCount
        instanceMemoryMB: instanceMemoryMB
      }
      runtime: {
        name: mcpRuntime
        version: mcpRuntimeVersion
      }
    }
    siteConfig: {
      appSettings: concat(
        [
          {
            name: 'AzureWebJobsStorage__credential'
            value: 'managedidentity'
          }
          {
            name: 'AzureWebJobsStorage__blobServiceUri'
            value: 'https://${storage.outputs.name}.blob.${environment().suffixes.storage}'
          }
          {
            name: 'AzureWebJobsStorage__queueServiceUri'
            value: 'https://${storage.outputs.name}.queue.${environment().suffixes.storage}'
          }
          {
            name: 'AzureWebJobsStorage__tableServiceUri'
            value: 'https://${storage.outputs.name}.table.${environment().suffixes.storage}'
          }
          {
            name: 'AzureFunctionsJobHost__extensionBundle__id'
            value: 'Microsoft.Azure.Functions.ExtensionBundle'
          }
          {
            name: 'AzureFunctionsJobHost__extensionBundle__version'
            value: '[4.0.0, 5.0.0)'
          }
        ],
        additionalAppSettingsArray
      )
    }
  }
}

// Role Assignments
@description('Principal ID for an optional user identity that requires access to Storage resources (primarily for testing).')
param userPrincipalId string = ''

@description('Enable role assignments for the optional user principal. Accepted values: "true", "false".')
param allowUserPrincipalAccessString string = 'false'
var allowUserPrincipalAccess = bool(allowUserPrincipalAccessString)

module rbacAssignments './modules/functionapp-rbac.bicep' = if (deployService && deployFunctionApp && deployStorageAccount) {
  name: 'functionapp-rbac'
  params: {
    storageAccountName: storage.outputs.name
    managedIdentityPrincipalId: functionApp.outputs.systemAssignedMIPrincipalId
    userPrincipalId: userPrincipalId
    allowUserPrincipal: allowUserPrincipalAccess
  }
}
