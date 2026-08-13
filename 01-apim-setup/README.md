# APIM Setup

Configure Azure API Management as a proxy to your external LLM provider.

## Setup

Follow these steps:

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
  --subscription-required true `
  --subscription-key-header-name "api-key" `
  --subscription-key-query-param-name "api-key"
```

> ⚠️ `--subscription-key-header-name "api-key"` is **required**. Foundry sends its
> credential in the `api-key` header; without this, APIM expects the default
> `Ocp-Apim-Subscription-Key` header and every call fails with 401.
>
> The alternative is to leave the APIM default alone and set `authConfig` on the Foundry
> connection instead, which tells Foundry which header name and value format to use. This
> sample takes the simpler route and configures APIM.

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

The XML files in `policies/` are the source of truth. Step 4 of `setup-apim.ps1`
reads each one, wraps it in the JSON body the management API expects, and PUTs it:

```powershell
$listXml = Get-Content policies\list-deployments.xml -Raw
@{ properties = @{ format = "rawxml"; value = $listXml } } |
  ConvertTo-Json -Depth 5 | Out-File -FilePath "list-policy.json" -Encoding UTF8

az rest --method PUT `
  --uri "$baseUri/operations/ListDeployments/policies/policy?api-version=2022-08-01" `
  --body "@list-policy.json"
```

To change a policy, edit the XML - never the generated JSON, which is deleted
after it is applied.

## Policies

| File | Operation | Purpose |
|------|-----------|---------|
| `list-deployments.xml` | ListDeployments | Return available models |
| `get-deployment.xml` | GetDeployment | Return model details |
| `chat-completions.xml` | ChatCompletions | Forward to backend with API key |

ListDeployments and GetDeployment exist only for dynamic model discovery. If the
Foundry connection uses a static model list, ChatCompletions is the only operation
you need.

`chat-completions.xml` keeps `YOUR_EXTERNAL_LLM_API_KEY` as a placeholder so the real
key is never committed; the script substitutes `$ExternalApiKey` when it applies the policy.

`list-deployments.xml` and `get-deployment.xml` return **mocked** responses. Microsoft's
[setup guide](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/apim-setup-guide-for-agents.md)
implements these two operations by proxying to Azure Resource Manager with a managed
identity, which only works when APIM fronts an Azure OpenAI or Foundry resource. An
external provider has no equivalent endpoint, so the model list is hardcoded in policy
instead. Keep the two files in sync: every model in `list-deployments.xml` needs a
matching branch in `get-deployment.xml`.

## Testing

```powershell
$apimKey = "<YOUR_APIM_SUBSCRIPTION_KEY>"
$apimEndpoint = "https://<APIM_NAME>.azure-api.net/compass"
$apiVersion = "2024-10-21"

# ListDeployments - should return both models
Invoke-RestMethod -Uri "$apimEndpoint/deployments?api-version=$apiVersion" -Headers @{"api-key"=$apimKey}

# GetDeployment - should return gpt-5
Invoke-RestMethod -Uri "$apimEndpoint/deployments/gpt-5?api-version=$apiVersion" -Headers @{"api-key"=$apimKey}

# GetDeployment for an unknown model - should return 404, not 200
Invoke-RestMethod -Uri "$apimEndpoint/deployments/does-not-exist?api-version=$apiVersion" -Headers @{"api-key"=$apimKey}

# ChatCompletions - the deployment comes from the path, not the body
$body = '{"messages":[{"role":"user","content":"Hello"}]}'
Invoke-RestMethod -Uri "$apimEndpoint/deployments/gpt-5/chat/completions?api-version=$apiVersion" `
  -Method POST -Headers @{"api-key"=$apimKey; "Content-Type"="application/json"} -Body $body
```
