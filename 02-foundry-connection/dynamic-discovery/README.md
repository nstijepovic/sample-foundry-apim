# Foundry Connection - Dynamic Model Discovery

Foundry calls the discovery endpoints on APIM at runtime to find out which models
are available, so APIM stays the single source of truth.

> ⚠️ **Read this first.** Microsoft's dynamic discovery instructions assume an Azure
> OpenAI or Foundry resource behind APIM, where the discovery operations proxy to Azure
> Resource Manager with a managed identity. An external provider like Compass has no such
> ARM endpoint, so this sample **mocks** the responses in policy instead. That works, but
> the model list is then maintained in APIM policy rather than discovered from anything -
> at which point [static-models/](../static-models/) gives you the same result with less
> machinery. The upstream guide says as much: *"For any other backend services, ensure you
> properly setup and test it out, otherwise use static discovery for simplicity."*

## APIM prerequisites

Both discovery operations must exist and return the `AzureOpenAI` response shape:

| Operation | Method | Path | Policy |
|-----------|--------|------|--------|
| ListDeployments | GET | `/deployments` | `01-apim-setup/policies/list-deployments.xml` |
| GetDeployment | GET | `/deployments/{deploymentName}` | `01-apim-setup/policies/get-deployment.xml` |
| ChatCompletions | POST | `/deployments/{deployment-id}/chat/completions` | `01-apim-setup/policies/chat-completions.xml` |

Every model returned by ListDeployments must also resolve through GetDeployment,
otherwise Foundry validates a model that cannot be served.

## Deploy

1. Copy `parameters.example.json` to `parameters.json`
2. Update the values in `parameters.json`
3. Deploy:

```powershell
az deployment group create `
  --resource-group <RESOURCE_GROUP> `
  --template-file connection.bicep `
  --parameters @parameters.json
```

## Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `accountName` | Foundry account name | `my-foundry-account` |
| `projectName` | Foundry project name | `my-project` |
| `connectionName` | Name for the connection | `compass-connection` |
| `targetUrl` | APIM endpoint URL | `https://my-apim.azure-api.net/compass` |
| `apiKey` | APIM subscription key | `abc123...` |
| `deploymentInPath` | Model name goes in the URL path | `true` |
| `inferenceAPIVersion` | API version for chat completions. Leave empty to let Foundry use its default | `2024-10-21` |
| `deploymentAPIVersion` | API version for discovery calls, if APIM requires one | `""` |
| `listModelsEndpoint` | List models endpoint | `/deployments` |
| `getModelEndpoint` | Get model endpoint | `/deployments/{deploymentName}` |
| `deploymentProvider` | Discovery response format, `AzureOpenAI` or `OpenAI` | `AzureOpenAI` |

Empty API versions are left out of the metadata entirely, because Foundry treats an
absent value and an empty string differently.

`listModelsEndpoint`, `getModelEndpoint`, and `deploymentProvider` are stored as a
serialized `modelDiscovery` object. These three values happen to be the APIM defaults
Foundry already assumes, so `modelDiscovery` is technically optional here - the template
emits it anyway so the connection documents its own contract.

## Response formats

`deploymentProvider` tells Foundry how to parse the discovery responses:

- `AzureOpenAI` - list returns `{"value": [...]}`, get returns a single object, each with
  `name` and `properties.model.{format,name,version}`. This is what the policies in
  `01-apim-setup/policies/` return.
- `OpenAI` - list returns `{"data": [...]}`, get returns a single object, each keyed by
  `id` with no version information.

## Using the Connection

```
<connection-name>/<deployment-name>
```

Example: `compass-connection/gpt-5`
