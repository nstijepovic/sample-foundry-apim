# Foundry Connection - Static Model List

The model list lives in the connection metadata. Foundry never calls APIM to
discover models, so the discovery operations are not needed.

## APIM prerequisites

| Operation | Method | Path | Policy |
|-----------|--------|------|--------|
| ChatCompletions | POST | `/deployments/{deployment-id}/chat/completions` | `01-apim-setup/policies/chat-completions.xml` |

ListDeployments and GetDeployment can be skipped entirely in this mode.

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
| `models` | Models exposed by this connection | see below |

An empty `inferenceAPIVersion` is left out of the metadata entirely, because Foundry
treats an absent value and an empty string differently.

## Model shape

Models are objects, not plain strings. `name` is the deployment name you call in
APIM; `properties.model` describes the underlying provider model. In the connection
metadata the list is a bare array:

```json
"models": [
  {
    "name": "gpt-5",
    "properties": {
      "model": { "name": "gpt-5", "version": "", "format": "OpenAI" }
    }
  }
]
```

In `parameters.json` the same array is wrapped in the ARM `"value"` envelope that
every parameter uses - see `parameters.example.json`.

### Choosing `format`

`format` names the provider contract the model speaks. The official reference gives
it as an open list - *"Provider format (OpenAI, DeepSeek, etc.)"* - rather than a
fixed set, so match it to your provider.

Compass exposes an OpenAI-compatible endpoint, so this sample uses `OpenAI`. Note that
a wrong value fails at tool-use time, not at connection time.

Redeploy this connection whenever the model list changes.

## Using the Connection

```
<connection-name>/<deployment-name>
```

Example: `compass-connection/gpt-5`
