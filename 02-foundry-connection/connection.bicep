/*
  Azure AI Foundry Connection to APIM
  
  Creates a connection from Azure AI Foundry to an external LLM
  provider through Azure API Management.
  
  MODEL DISCOVERY:
  - Dynamic (default): Leave staticModels empty. Foundry will call the
    ListDeployments endpoint on APIM to discover available models.
  - Static: Provide a list of models in staticModels. Foundry will use
    this list directly without calling ListDeployments.
  
  Usage:
    az deployment group create \
      --resource-group <RESOURCE_GROUP> \
      --template-file connection.bicep \
      --parameters @parameters.json
*/

// =============================================================================
// PARAMETERS
// =============================================================================

@description('The name of the Foundry account')
param accountName string

@description('The name of the Foundry project')
param projectName string

@description('The name of the connection')
param connectionName string

@description('The APIM endpoint URL (e.g., https://myapim.azure-api.net/compass)')
param targetUrl string

@description('The APIM subscription key')
@secure()
param apiKey string

@description('Whether deployment name is in URL path')
param deploymentInPath string = 'true'

@description('API version for inference calls')
param inferenceAPIVersion string = '2024-10-21'

@description('Static list of models. Leave empty for dynamic discovery (Foundry calls ListDeployments). Provide models to skip the API call.')
param staticModels array = []

// =============================================================================
// EXISTING RESOURCES
// =============================================================================

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  parent: account
  name: projectName
}

// =============================================================================
// CONNECTION
// =============================================================================

resource connection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: project
  name: connectionName
  properties: {
    category: 'ApiManagement'
    target: targetUrl
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: apiKey
    }
    metadata: empty(staticModels) ? {
      deploymentInPath: deploymentInPath
      inferenceAPIVersion: inferenceAPIVersion
    } : {
      deploymentInPath: deploymentInPath
      inferenceAPIVersion: inferenceAPIVersion
      models: string(staticModels)
    }
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output connectionId string = connection.id
output connectionName string = connection.name
