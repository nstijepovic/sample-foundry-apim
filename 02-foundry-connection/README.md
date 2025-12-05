# Foundry Connection

Create a connection in Azure AI Foundry that points to your APIM.

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

## Connection Properties

| Property | Value | Description |
|----------|-------|-------------|
| `category` | `ApiManagement` | Tells Foundry this is an APIM proxy |
| `authType` | `ApiKey` | Uses API key authentication |
| `deploymentInPath` | `true` | Model name goes in URL path |
| `inferenceAPIVersion` | `2024-10-21` | OpenAI API version |

## Using the Connection

After deployment, reference models as:

```
<connection-name>/<deployment-name>
```

Example: `compass-connection/gpt-5`
