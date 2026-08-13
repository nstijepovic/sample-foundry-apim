/*
  Azure AI Foundry Connection to APIM - Static Model List

  Creates a connection from Azure AI Foundry to an external LLM
  provider through Azure API Management.

  The model list is stored in the connection metadata, so Foundry never calls
  APIM to discover models. Adding or removing a model means redeploying this
  connection.

  APIM PREREQUISITES:
    POST /deployments/{deployment-id}/chat/completions -> chat-completions.xml

  The ListDeployments and GetDeployment operations are NOT required in this mode.

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

@description('Models exposed by this connection. Each entry needs a deployment name plus properties.model.{name,version,format}.')
@minLength(1)
param models array

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
    models: string(models)
  },
  empty(inferenceAPIVersion)
    ? {}
    : {
        inferenceAPIVersion: inferenceAPIVersion
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
