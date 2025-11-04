using './mcpservices.bicep'

// Common
param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}

// Service
param deployServiceString = '#{{ deployService }}'
param deployFunctionAppString = '#{{ deployFunctionApp }}'

// Virtual Network
param virtualNetworkName = '#{{ vnet-001-name }}'
param virtualNetworkResourceGroupName = '#{{ networkResourceGroup }}'
param mcpSubnetName = '#{{ snet-002-name }}'

// Resource names
param hostingPlanName = '#{{ mcpPlanName }}'
param mcpFunctionAppName = '#{{ mcpFunctionAppName }}'
param storageAccountName = '#{{ mcpStorageAccountName }}'
param logAnalyticsWorkspaceName = '#{{ mcpLogAnalyticsName }}'
param applicationInsightsName = '#{{ mcpInsightsName }}'
param deploymentContainerName = '#{{ mcpDeploymentContainerName }}'

// Function App configuration
param maximumInstanceCountString = '#{{ mcpMaximumInstanceCount }}'
param instanceMemoryMBString = '#{{ mcpInstanceMemoryMB }}'
param mcpRuntime = '#{{ mcpRuntime }}'
param mcpRuntimeVersion = '#{{ mcpRuntimeVersion }}'
param alwaysReadyDurableCountString = '#{{ mcpAlwaysReadyDurableCount }}'
param zoneRedundantString = '#{{ mcpPlanZoneRedundant }}'

// Identity
param userPrincipalId = '#{{ mcpUserPrincipalId }}'
param allowUserPrincipalAccessString = '#{{ mcpAllowUserPrincipal }}'
