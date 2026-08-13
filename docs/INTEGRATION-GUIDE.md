# Connecting Microsoft Foundry to External LLMs via APIM

> **Complete Guide**: How to use Azure API Management (APIM) to connect Microsoft Foundry to any OpenAI-compatible external LLM provider.

---

## Official Microsoft Documentation

Before proceeding, review these official resources:

| Resource | Link |
|----------|------|
| **Bring your own AI gateway** | [Microsoft Learn](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/tools/bring-your-own-ai-gateway) |
| **APIM Setup Guide for Foundry Agents** | [GitHub - foundry-samples](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/apim-setup-guide-for-agents.md) |
| **APIM Connection Objects (metadata reference)** | [GitHub - foundry-samples](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/APIM-Connection-Objects.md) |
| **Troubleshooting Guide** | [GitHub - foundry-samples](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/troubleshooting-guide.md) |
| **Microsoft Foundry Connections** | [Microsoft Learn](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/connections-add) |

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Part 1: Configure APIM as a Proxy](#part-1-configure-apim-as-a-proxy)
3. [Part 2: Create Foundry Connection](#part-2-create-foundry-connection)
4. [Part 3: Use the Connection in Foundry](#part-3-use-the-connection-in-foundry)
5. [Reference](#reference)

---

## Prerequisites

### Required Resources

| Resource | Purpose |
|----------|---------|
| Azure Subscription | Host APIM and Foundry |
| Azure API Management | Proxy to external LLM |
| Microsoft Foundry Account | Create agents and workflows |
| Microsoft Foundry Project | Container for connections and agents |
| External LLM API Key | Access to external LLM (e.g., Core42 Compass) |

### Tools

- Azure CLI (`az`) installed and logged in
- PowerShell or Bash terminal

---

## Part 1: Configure APIM as a Proxy

Microsoft Foundry expects an OpenAI-compatible API with specific endpoints. We'll configure APIM to expose these endpoints and proxy requests to the external LLM.

### Step 1.1: Create the API


```powershell
az apim api create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --display-name "Compass API" `
    --path $ApiPath `
    --service-url $BackendUrl `
    --protocols https `
    --subscription-required true `
    --subscription-key-header-name "api-key" `
    --subscription-key-query-param-name "api-key"
```

**Parameters:**

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--api-id` | `compass-api` | Unique identifier for the API |
| `--path` | `compass` | URL path prefix (e.g., `/compass`) |
| `--service-url` | `https://api.core42.ai/openai` | Backend LLM endpoint |
| `--subscription-required` | `true` | Require API key for access |
| `--subscription-key-header-name` | `api-key` | **Required for Foundry** - use `api-key` header instead of default |
| `--subscription-key-query-param-name` | `api-key` | Query param name for API key |

---

### Step 1.2: Create Required Operations


#### Operation 1: ListDeployments

Returns a list of available models. Foundry calls this to discover what models are available through the connection.

```powershell
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --operation-id ListDeployments `
    --display-name "ListDeployments" `
    --method GET `
    --url-template "/deployments"
```

#### Operation 2: GetDeployment

Returns details for a specific model. Foundry calls this to validate a model exists.

```powershell
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --operation-id GetDeployment `
    --display-name "GetDeployment" `
    --method GET `
    --url-template "/deployments/{deploymentName}" `
    --template-parameters name=deploymentName type=string required=true
```

#### Operation 3: ChatCompletions

The actual inference endpoint. Foundry sends chat messages here.

```powershell
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --operation-id ChatCompletions `
    --display-name "ChatCompletions" `
    --method POST `
    --url-template "/deployments/{deployment-id}/chat/completions" `
    --template-parameters name=deployment-id type=string required=true
```

---

### Step 1.3: Apply Policies

Policies are defined in `01-apim-setup/policies/*.xml` and applied via `az rest` with a
JSON wrapper. See `01-apim-setup/setup-apim.ps1` for the full sequence.

```powershell
$baseUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/apis/$ApiId"

# Apply ListDeployments policy
az rest --method PUT --uri "$baseUri/operations/ListDeployments/policies/policy?api-version=2022-08-01" --body "@list-policy.json"

# Apply GetDeployment policy
az rest --method PUT --uri "$baseUri/operations/GetDeployment/policies/policy?api-version=2022-08-01" --body "@get-policy.json"

# Apply ChatCompletions policy
az rest --method PUT --uri "$baseUri/operations/ChatCompletions/policies/policy?api-version=2022-08-01" --body "@chat-policy.json"
```

> ⚠️ **Security Note**: Store your external LLM API key securely. Consider using [Named Values](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-properties) or Key Vault for production.

---

### Step 1.4: Test APIM Endpoints

Before connecting Foundry, verify APIM works correctly:

```powershell
$apimKey = "YOUR_APIM_SUBSCRIPTION_KEY"  # Get from Azure Portal > APIM > Subscriptions

# Test ListDeployments
Invoke-RestMethod -Uri "https://$ApimName.azure-api.net/$ApiPath/deployments?api-version=2024-10-21" -Headers @{"api-key"=$apimKey}

# Test GetDeployment
Invoke-RestMethod -Uri "https://$ApimName.azure-api.net/$ApiPath/deployments/gpt-5?api-version=2024-10-21" -Headers @{"api-key"=$apimKey}

# Test ChatCompletions
$resp = Invoke-RestMethod -Uri "https://$ApimName.azure-api.net/$ApiPath/deployments/gpt-5/chat/completions?api-version=2024-10-21" `
    -Headers @{"api-key"=$apimKey; "Content-Type"="application/json"} `
    -Method POST -Body '{"messages":[{"role":"user","content":"Hello"}]}'
$resp.choices[0].message.content
```

---

## Part 2: Create Foundry Connection

Now we'll create a connection in Microsoft Foundry that points to our APIM.

### Step 2.0: Choose a Model Discovery Mode

A connection uses either a static model list or dynamic discovery - never both.

| Mode | Folder | Models come from | APIM operations needed |
|------|--------|------------------|------------------------|
| Static | `02-foundry-connection/static-models` | `models` in the connection metadata | ChatCompletions |
| Dynamic | `02-foundry-connection/dynamic-discovery` | Foundry calling the discovery endpoints | ChatCompletions + ListDeployments + GetDeployment |

Microsoft's guide documents dynamic discovery for APIM instances backed by Azure OpenAI
or Foundry, where the discovery operations proxy to Azure Resource Manager. For any other
backend - Compass included - it recommends static discovery for simplicity. This sample
supports both: the dynamic path mocks the two discovery endpoints in APIM policy.

### Step 2.1: Deploy Using Bicep

Deploy from the folder for the mode you picked:

```powershell
az deployment group create `
  --resource-group <RESOURCE_GROUP> `
  --template-file connection.bicep `
  --parameters @parameters.json
```

> 💡 The upstream repo ships a
> [validation script](https://github.com/microsoft-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim/test_apim_connection.py)
> that exercises a parameter file against a live APIM before you create the connection.

### Step 2.2: Verify Connection

You can verify the connection was created in:
- **Azure Portal**: AI Foundry → Project → Settings → Connections

---

## Part 3: Use the Connection in Foundry

### Step 3.1: Model Reference Format

When using the connection, reference models in this format:

```
<connection-name>/<deployment-name>
```

**Examples:**
- `compass-connection/gpt-5`
- `compass-connection/gpt-4.1`

### Step 3.2: Create an Agent

See `../03-agent-samples/create_agent.py` for a complete example.

### Step 3.3: Use in Foundry Portal

1. Go to **AI Foundry** → **Your Project**
2. Navigate to **Agents** → **Create Agent**
3. In **Model** dropdown, select `compass-connection/gpt-5`
4. Configure instructions and tools
5. **Save** and test in the playground

---

## Reference

### Connection Properties

| Property | Value | Description |
|----------|-------|-------------|
| `category` | `ApiManagement` | Tells Foundry this is an APIM proxy |
| `authType` | `ApiKey` | Authentication method |
| `target` | APIM URL | Base URL for API calls |
| `isSharedToAll` | `true` | Shares the connection with all project users. Upstream defaults to `false` |

### Connection Metadata

Complex values (objects, arrays) are stored as serialized JSON strings.

| Key | Mode | Description |
|-----|------|-------------|
| `deploymentInPath` | both | `"true"` when the URL is `/deployments/{name}/chat/completions`, `"false"` when the model is passed in the body |
| `inferenceAPIVersion` | both | `api-version` for inference calls. Omit to use Foundry's default |
| `deploymentAPIVersion` | dynamic | `api-version` for discovery calls only. Omit to send no query param |
| `modelDiscovery` | dynamic | `listModelsEndpoint`, `getModelEndpoint`, `deploymentProvider`. Optional when using the APIM defaults `/deployments`, `/deployments/{deploymentName}`, `AzureOpenAI` |
| `models` | static | Model list as `name` + `properties.model.{name,version,format}` |
| `authConfig` | optional | Changes the header name and value format used to send the APIM key, e.g. `x-api-key` or `Bearer {api_key}`. An alternative to setting `--subscription-key-header-name` on the API |
| `customHeaders` | optional | Extra headers attached to every inference call |

### Model `format` Values

`format` names the provider contract the model speaks. The official reference gives it
as an open list - *"Provider format (OpenAI, DeepSeek, etc.)"* - rather than a fixed
set, so match it to your provider. Compass is OpenAI-compatible, so this sample uses
`OpenAI`. A wrong value fails at tool-use time, not at connection time.

### Discovery Response Formats

| `deploymentProvider` | List response | Get response |
|----------------------|---------------|--------------|
| `AzureOpenAI` | `{"value": [ { "name", "properties": { "model": {...} } } ]}` | single object of the same shape |
| `OpenAI` | `{"data": [ { "id", "object", ... } ]}` | single object keyed by `id` |

### Required APIM Operations

| Operation | Method | Path | Purpose |
|-----------|--------|------|---------|
| ListDeployments | GET | `/deployments` | Discover available models |
| GetDeployment | GET | `/deployments/{name}` | Validate model exists |
| ChatCompletions | POST | `/deployments/{id}/chat/completions` | Inference calls |

ListDeployments and GetDeployment are only needed for dynamic discovery. With a
static model list, ChatCompletions is the only required operation.
