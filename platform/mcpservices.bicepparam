using './mcpservices.bicep'

// Common
param tags = {
  environment: '#{{ environment }}'
  owner: '#{{ owner }}'
  service: '#{{ service }}'
}

// Service
param deployServiceString = '#{{ deployService }}'

// Virtual Network
param virtualNetworkName = '#{{ vnet-001-name }}'
param mcpSubnetName = '#{{ snet-002-name }}'
param virtualNetworkResourceGroupName = '#{{ networkResourceGroup }}'

// Storage Account
param deployStorageAccountString = '#{{ deployStorageAccount }}'
param storageAccountName = '#{{ mcpStorageAccountName }}'
param deploymentContainerName = '#{{ mcpDeploymentContainerName }}'

// Hosting Plan
param deployHostingPlanString = '#{{ deployHostingPlan }}'
param hostingPlanName = '#{{ mcpPlanName }}'
param zoneRedundantString = '#{{ mcpPlanZoneRedundant }}'

// Function App
param deployFunctionAppString = '#{{ deployFunctionApp }}'
param mcpFunctionAppName = '#{{ mcpFunctionAppName }}'
param maximumInstanceCountString = '#{{ mcpMaximumInstanceCount }}'
param instanceMemoryMBString = '#{{ mcpInstanceMemoryMB }}'
param mcpRuntime = '#{{ mcpRuntime }}'
param mcpRuntimeVersion = '#{{ mcpRuntimeVersion }}'

// Role Assignments
param userPrincipalId = '#{{ mcpUserPrincipalId }}'
param allowUserPrincipalAccessString = '#{{ mcpAllowUserPrincipal }}'
