# Connecting Microsoft Foundry to External LLMs via APIM

> **Complete Guide**: How to use Azure API Management (APIM) to connect Microsoft Foundry to any OpenAI-compatible external LLM provider.

---

## Official Microsoft Documentation

Before proceeding, review these official resources:

| Resource | Link |
|----------|------|
| **Bring your own AI gateway** | [Microsoft Learn](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/tools/bring-your-own-ai-gateway) |
| **APIM Integration Samples** | [GitHub - foundry-samples](https://github.com/azure-ai-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim-and-modelgateway-integration-guide.md) |
| **Microsoft Foundry Connections** | [Microsoft Learn](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/connections-add) |

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Part 1: Configure APIM as a Proxy](#part-1-configure-apim-as-a-proxy)
4. [Part 2: Create Foundry Connection](#part-2-create-foundry-connection)
5. [Part 3: Use the Connection in Foundry](#part-3-use-the-connection-in-foundry)
6. [Troubleshooting](#troubleshooting)
7. [Reference](#reference)

---

## Architecture Overview

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│                     │     │                     │     │                     │
│  Microsoft Foundry  │────▶│   Azure API         │────▶│   External LLM      │
│                     │     │   Management        │     │   Provider          │
│   • Agents          │     │                     │     │                     │
│   • Workflows       │     │   • Authentication  │     │   • Core42 Compass  │
│   • Tools           │     │   • Rate Limiting   │     │   • OpenAI          │
│   • Evaluations     │     │   • Logging         │     │   • Anthropic       │
│                     │     │   • Transformations │     │   • Any OpenAI-     │
│                     │     │                     │     │     compatible API  │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
        │                           │                           │
        │   APIM Subscription Key   │   External LLM API Key    │
        │◀──────────────────────────│◀──────────────────────────│
        │   (stored in Foundry)     │   (stored in APIM policy) │
```

### Why This Pattern?

| Benefit | Description |
|---------|-------------|
| **Use Any LLM** | Connect Foundry to any OpenAI-compatible API |
| **Secure Keys** | External LLM keys stay in APIM, not exposed to users |
| **Centralized Control** | Rate limiting, logging, and policies in one place |
| **Full Foundry Features** | Use agents, tools, workflows, evaluations with external LLMs |

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
  --resource-group <RESOURCE_GROUP> `
  --service-name <APIM_NAME> `
  --api-id compass-api `
  --display-name "Compass API" `
  --path compass `
  --service-url "https://api.core42.ai/openai" `
  --protocols https `
  --subscription-required true
```

**Parameters:**

| Parameter | Value | Description |
|-----------|-------|-------------|
| `--api-id` | `compass-api` | Unique identifier for the API |
| `--path` | `compass` | URL path prefix (e.g., `/compass`) |
| `--service-url` | `https://api.core42.ai/openai` | Backend LLM endpoint |
| `--subscription-required` | `true` | Require APIM subscription key |

---

### Step 1.2: Create Required Operations

Foundry requires **3 specific operations** to work with an `ApiManagement` connection:

#### Operation 1: ListDeployments

Returns a list of available models. Foundry calls this to discover what models are available through the connection.

```powershell
az apim api operation create `
  --resource-group <RESOURCE_GROUP> `
  --service-name <APIM_NAME> `
  --api-id compass-api `
  --operation-id ListDeployments `
  --display-name "ListDeployments" `
  --method GET `
  --url-template "/deployments"
```

#### Operation 2: GetDeployment

Returns details for a specific model. Foundry calls this to validate a model exists.

```powershell
az apim api operation create `
  --resource-group <RESOURCE_GROUP> `
  --service-name <APIM_NAME> `
  --api-id compass-api `
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
  --resource-group <RESOURCE_GROUP> `
  --service-name <APIM_NAME> `
  --api-id compass-api `
  --operation-id ChatCompletions `
  --display-name "ChatCompletions" `
  --method POST `
  --url-template "/deployments/{deployment-id}/chat/completions" `
  --template-parameters name=deployment-id type=string required=true
```

---

### Step 1.3: Apply Policies

APIM policies control how requests are processed. We need policies for each operation.

See the policy files in `../01-apim-setup/policies/` for the full XML content.

#### Policy for ListDeployments

This policy returns a **static JSON response** listing available models. The request never reaches the backend.

#### Policy for GetDeployment

This policy dynamically returns model details based on the URL path parameter.

#### Policy for ChatCompletions

This is the **critical policy** - it adds the external LLM's API key and forwards the request to the backend.

> ⚠️ **Security Note**: Store your external LLM API key securely. Consider using [Named Values](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-properties) or Key Vault for production.

---

### Step 1.4: Test APIM Endpoints

Before connecting Foundry, verify APIM works correctly:

```powershell
# Set your APIM subscription key
$apimKey = "<YOUR_APIM_SUBSCRIPTION_KEY>"
$apimEndpoint = "https://<APIM_NAME>.azure-api.net/compass"

# Test 1: ListDeployments
Write-Host "Testing ListDeployments..."
Invoke-RestMethod -Uri "$apimEndpoint/deployments" `
  -Headers @{"api-key"=$apimKey}

# Test 2: GetDeployment
Write-Host "Testing GetDeployment..."
Invoke-RestMethod -Uri "$apimEndpoint/deployments/gpt-5" `
  -Headers @{"api-key"=$apimKey}

# Test 3: ChatCompletions
Write-Host "Testing ChatCompletions..."
$body = '{"model":"gpt-5","messages":[{"role":"user","content":"Say hello"}]}'
$result = Invoke-RestMethod -Uri "$apimEndpoint/deployments/gpt-5/chat/completions" `
  -Method POST `
  -Headers @{"api-key"=$apimKey; "Content-Type"="application/json"} `
  -Body $body
$result.choices[0].message.content
```

---

## Part 2: Create Foundry Connection

Now we'll create a connection in Microsoft Foundry that points to our APIM.

### Step 2.1: Deploy Using Bicep

```powershell
az deployment group create `
  --resource-group <RESOURCE_GROUP> `
  --template-file connection.bicep `
  --parameters @parameters.json
```

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

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `401 Unauthorized` on APIM | Wrong APIM subscription key | Verify key in parameters file |
| `404 Not Found` on ListDeployments | Operation not created | Create the operation in APIM |
| Model not appearing in Foundry | Connection not deployed | Verify Bicep deployment succeeded |
| `Invalid model` error | Wrong model format | Use `connection-name/deployment-name` |
| Backend timeout | External LLM unreachable | Check APIM → Backend → health |

---

## Reference

### Connection Properties

| Property | Value | Description |
|----------|-------|-------------|
| `category` | `ApiManagement` | Tells Foundry this is an APIM proxy |
| `authType` | `ApiKey` | Authentication method |
| `target` | APIM URL | Base URL for API calls |
| `deploymentInPath` | `true` | Model name goes in URL path |
| `inferenceAPIVersion` | `2024-10-21` | OpenAI API version |

### Required APIM Operations

| Operation | Method | Path | Purpose |
|-----------|--------|------|---------|
| ListDeployments | GET | `/deployments` | Discover available models |
| GetDeployment | GET | `/deployments/{name}` | Validate model exists |
| ChatCompletions | POST | `/deployments/{id}/chat/completions` | Inference calls |
