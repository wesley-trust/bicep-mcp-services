targetScope = 'resourceGroup'

// Common
@description('Azure region to deploy resources. Defaults to the current resource group location.')
param location string = resourceGroup().location

@description('Optional tags applied to the resources created by this module.')
param tags object = {}
var normalisedTags = empty(tags) ? null : tags

// Service
@description('Flag to determine whether to deploy the service. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployServiceString string
var deployService = bool(deployServiceString)

@description('Flag to determine whether to deploy the Function App resources. Set to true to deploy, false to skip deployment. Accepted values: "true", "false".')
param deployFunctionAppString string
var deployFunctionApp = bool(deployFunctionAppString)

// Virtual Network
@description('Name of the virtual network that hosts the Function App integration subnet.')
param virtualNetworkName string

@description('Resource group that contains the hosting virtual network.')
param virtualNetworkResourceGroupName string

@description('Subnet dedicated for the workload integration.')
param mcpSubnetName string

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-07-01' existing = if (deployService && deployFunctionApp) {
  scope: resourceGroup(virtualNetworkResourceGroupName)
  name: virtualNetworkName
}

resource mcpSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = if (deployService && deployFunctionApp) {
  name: mcpSubnetName
  parent: virtualNetwork
}

// Function App naming
@description('Name of the Azure Functions Flex Consumption plan to create.')
param hostingPlanName string

@description('Name of the Function App to create.')
param mcpFunctionAppName string

@description('Name of the Storage Account for the Function App.')
param storageAccountName string

@description('Blob container name used for deployment packages (zip deploy).')
param deploymentContainerName string

// Function App configuration
@description('Maximum number of instances for the Function App scale controller.')
param maximumInstanceCountString string = '100'

@allowed([
  '512'
  '2048'
  '4096'
])
@description('Instance memory allocation in MB for Flex Consumption workers.')
param instanceMemoryMBString string = '2048'

@description('Function App runtime stack.')
param mcpRuntime string = 'powerShell'

@description('Runtime version used by the Function App runtime stack.')
param mcpRuntimeVersion string = '7.4'

@description('Optional count of always ready instances for Durable Functions workloads. Leave at 0 to allow scaling to zero.')
param alwaysReadyDurableCountString string = '0'

@description('Optional map of application settings to merge with the default set.')
param additionalAppSettings object = {}

@description('Flag to enable zone redundancy on the Flex Consumption plan.')
param zoneRedundantString string = 'false'

// Converted parameters
var maximumInstanceCount = int(maximumInstanceCountString)
var instanceMemoryMB = int(instanceMemoryMBString)
var alwaysReadyDurableCount = int(alwaysReadyDurableCountString)
var zoneRedundant = bool(zoneRedundantString)

@description('Principal ID for an optional user identity that requires access to Storage resources (primarily for testing).')
param userPrincipalId string = ''

@description('Enable role assignments for the optional user principal. Accepted values: "true", "false".')
param allowUserPrincipalAccessString string = 'false'
var allowUserPrincipalAccess = bool(allowUserPrincipalAccessString)

// Storage
module storage 'br/public:avm/res/storage/storage-account:0.25.0' = if (deployService && deployFunctionApp) {
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

// Hosting plan
module hostingPlan 'br/public:avm/res/web/serverfarm:0.1.1' = if (deployService && deployFunctionApp) {
  name: 'hostingplan'
  params: {
    name: hostingPlanName
    location: location
    tags: normalisedTags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
    reserved: true
    zoneRedundant: zoneRedundant
  }
}

// Function App app settings
var baseAppSettings = {
  AzureWebJobsStorage__credential: 'managedidentity'
  AzureWebJobsStorage__blobServiceUri: 'https://${storage.outputs.name}.blob.${environment().suffixes.storage}'
  AzureWebJobsStorage__queueServiceUri: 'https://${storage.outputs.name}.queue.${environment().suffixes.storage}'
  AzureWebJobsStorage__tableServiceUri: 'https://${storage.outputs.name}.table.${environment().suffixes.storage}'
  AzureFunctionsJobHost__extensionBundle__id: 'Microsoft.Azure.Functions.ExtensionBundle'
  AzureFunctionsJobHost__extensionBundle__version: '[4.0.0, 5.0.0)'
}

var mergedAppSettings = union(baseAppSettings, additionalAppSettings)

// Function App
module functionApp 'br/public:avm/res/web/site:0.16.0' = if (deployService && deployFunctionApp) {
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
    siteConfig: {
      alwaysOn: false
      virtualNetworkSubnetId: mcpSubnet.id
    }
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
        alwaysReady: union(
          {
            durable: alwaysReadyDurableCount
          },
          {}
        )
      }
      runtime: {
        name: mcpRuntime
        version: mcpRuntimeVersion
      }
    }
    configs: [
      {
        name: 'appsettings'
        properties: mergedAppSettings
      }
    ]
  }
}

// Role assignments
module rbacAssignments './modules/functionapp-rbac.bicep' = if (deployService && deployFunctionApp) {
  name: 'functionapp-rbac'
  params: {
    storageAccountName: storage.outputs.name
    applicationInsightsName: applicationInsights.outputs.name
    managedIdentityPrincipalId: functionApp.outputs.?systemAssignedMIPrincipalId ?? ''
    userPrincipalId: userPrincipalId
    allowUserPrincipal: allowUserPrincipalAccess
  }
}
