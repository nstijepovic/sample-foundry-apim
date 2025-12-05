# APIM Setup

Configure Azure API Management as a proxy to your external LLM provider.

## Quick Setup

Run the setup script:

```powershell
./setup-apim.ps1 `
  -SubscriptionId "<SUBSCRIPTION_ID>" `
  -ResourceGroup "<RESOURCE_GROUP>" `
  -ApimName "<APIM_NAME>" `
  -BackendUrl "https://api.core42.ai/openai" `
  -ExternalApiKey "<EXTERNAL_LLM_API_KEY>" `
  -Models @("gpt-4.1", "gpt-5")
```

## Manual Setup

If you prefer to set up manually, follow these steps:

### 1. Create the API

```powershell
az apim api create `
  --resource-group <RESOURCE_GROUP> `
  --service-name <APIM_NAME> `
  --api-id compass-api `
  --display-name "Compass API" `
  --path compass `
  --service-url "https://api.core42.ai/openai" `
  --protocols https `
  --subscription-required true
```

### 2. Create Operations

```powershell
# ListDeployments
az apim api operation create `
  --resource-group <RESOURCE_GROUP> `
  --service-name <APIM_NAME> `
  --api-id compass-api `
  --operation-id ListDeployments `
  --display-name "ListDeployments" `
  --method GET `
  --url-template "/deployments"

# GetDeployment
az apim api operation create `
  --resource-group <RESOURCE_GROUP> `
  --service-name <APIM_NAME> `
  --api-id compass-api `
  --operation-id GetDeployment `
  --display-name "GetDeployment" `
  --method GET `
  --url-template "/deployments/{deploymentName}" `
  --template-parameters name=deploymentName type=string required=true

# ChatCompletions
az apim api operation create `
  --resource-group <RESOURCE_GROUP> `
  --service-name <APIM_NAME> `
  --api-id compass-api `
  --operation-id ChatCompletions `
  --display-name "ChatCompletions" `
  --method POST `
  --url-template "/deployments/{deployment-id}/chat/completions" `
  --template-parameters name=deployment-id type=string required=true
```

### 3. Apply Policies

Apply the policies from the `policies/` folder to each operation.

## Policies

| File | Operation | Purpose |
|------|-----------|---------|
| `list-deployments.xml` | ListDeployments | Return available models |
| `get-deployment.xml` | GetDeployment | Return model details |
| `chat-completions.xml` | ChatCompletions | Forward to backend with API key |

## Testing

```powershell
$apimKey = "<YOUR_APIM_SUBSCRIPTION_KEY>"
$apimEndpoint = "https://<APIM_NAME>.azure-api.net/compass"

# Test ListDeployments
Invoke-RestMethod -Uri "$apimEndpoint/deployments" -Headers @{"api-key"=$apimKey}

# Test ChatCompletions
$body = '{"model":"gpt-5","messages":[{"role":"user","content":"Hello"}]}'
Invoke-RestMethod -Uri "$apimEndpoint/deployments/gpt-5/chat/completions" `
  -Method POST -Headers @{"api-key"=$apimKey; "Content-Type"="application/json"} -Body $body
```
