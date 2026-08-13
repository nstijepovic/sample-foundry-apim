/*
  Azure AI Foundry Connection to APIM - Dynamic Model Discovery

  Creates a connection from Azure AI Foundry to an external LLM
  provider through Azure API Management.

  Foundry discovers models at runtime by calling the discovery endpoints on
  APIM, so APIM stays the single source of truth for available models.

  APIM PREREQUISITES:
    GET /deployments                   -> list-deployments.xml
    GET /deployments/{deploymentName}  -> get-deployment.xml

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

@description('API version for inference calls. Leave empty if the gateway does not require one.')
param inferenceAPIVersion string = '2024-10-21'

@description('API version appended to model discovery calls. Leave empty if the gateway does not require one.')
param deploymentAPIVersion string = ''

@description('Endpoint used to list models. Must match the APIM ListDeployments operation.')
param listModelsEndpoint string = '/deployments'

@description('Endpoint used to get one model. Must contain the {deploymentName} placeholder.')
param getModelEndpoint string = '/deployments/{deploymentName}'

@description('Response format Foundry expects from the discovery endpoints.')
@allowed([
  'AzureOpenAI'
  'OpenAI'
])
param deploymentProvider string = 'AzureOpenAI'

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
// METADATA
// =============================================================================

// Complex metadata values are stored as serialized JSON strings.
// An empty API version is omitted entirely - Foundry treats absent and empty differently.
var metadata = union(
  {
    deploymentInPath: deploymentInPath
    modelDiscovery: string({
      listModelsEndpoint: listModelsEndpoint
      getModelEndpoint: getModelEndpoint
      deploymentProvider: deploymentProvider
    })
  },
  empty(inferenceAPIVersion)
    ? {}
    : {
        inferenceAPIVersion: inferenceAPIVersion
      },
  empty(deploymentAPIVersion)
    ? {}
    : {
        deploymentAPIVersion: deploymentAPIVersion
      }
)

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
    metadata: metadata
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output connectionId string = connection.id
output connectionName string = connection.name
