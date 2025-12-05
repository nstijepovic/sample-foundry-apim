# Microsoft Foundry + APIM Integration

> Connect Microsoft Foundry to any OpenAI-compatible LLM provider through Azure API Management (APIM).

⚠️ **This is a sample implementation** to demonstrate how to integrate Microsoft Foundry with external LLM providers via APIM. It was created to make the integration work based on the official documentation.

## Required Reading

Before starting, **read these resources** to understand the approaches and architecture:

| Resource | Description |
|----------|-------------|
| [🔗 AI Gateway in Microsoft Foundry](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/ai-gateway?view=foundry) | **Start here** - Official guide explaining AI Gateway options |
| [🔗 APIM and Model Gateway Integration Guide](https://github.com/azure-ai-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim-and-modelgateway-integration-guide.md) | Detailed Bicep templates and step-by-step instructions |
| [Bring your own AI gateway to Azure AI Agent Service](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/tools/bring-your-own-ai-gateway) | Additional documentation for APIM integration |

## Limitations (Public Preview)

> ⚠️ This feature is in **public preview**.

- **CLI and SDK only** - You can only use this feature using the Azure CLI and SDK
- **Prompt Agents only** - Supported by Prompt Agents in the Agent SDK
- **Networking**:
  - Public networking is supported for APIM or self-hosted gateways
  - For full network isolation, use Foundry with Standard Secured Agents with virtual network injection
  - For APIM with full network isolation, deploy Foundry and APIM following [this GitHub template](https://github.com/azure-ai-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep)
  - For self-hosted gateways with full network isolation, ensure endpoints are accessible inside the virtual network injection used by the Agent service
- **Supported Agent tools**: CodeInterpreter, Functions, File Search, OpenAPI, Foundry IQ, Sharepoint Grounding, Fabric Data Agent, MCP, and Browser Automation
- **Different from built-in AI Gateway** - This feature is different from the "AI Gateway in Foundry" feature where a new, unique APIM instance is deployed with your Foundry resource. For that feature, see [Enforce token limits with AI Gateway](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/ai-gateway-overview)

## Overview

This repository provides templates and scripts to:

1. **Configure APIM** as a proxy to external LLM providers (e.g., Core42 Compass, OpenAI, Anthropic)
2. **Create a Foundry Connection** that uses the APIM proxy
3. **Build Agents** in Microsoft Foundry that leverage external LLMs

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│  Microsoft Foundry  │────▶│   Azure API         │────▶│   External LLM      │
│   (Agents, Tools)   │     │   Management        │     │   Provider          │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
```

## Quick Start

> 📝 **Note:** The PowerShell script `01-apim-setup/setup-apim.ps1` is a **collection of steps to run**. Due to potential network issues, run each step individually in your terminal rather than executing the full script. Copy and paste each section one at a time.

### Prerequisites

- Azure subscription with:
  - Azure API Management instance
  - Microsoft Foundry account and project
- External LLM API key (e.g., Core42 Compass)
- Azure CLI installed

### Step 1: Configure APIM

Review and run the steps in `01-apim-setup/setup-apim.ps1` individually:

```powershell
cd 01-apim-setup
# Open setup-apim.ps1 and run each step separately
```

### Step 2: Deploy Foundry Connection

```powershell
cd ../02-foundry-connection
az deployment group create --resource-group "my-rg" --template-file connection.bicep --parameters @parameters.json
```

### Step 3: Create and Test Agent

```powershell
cd ../03-agent-samples
uv sync
uv run test_connection.py
uv run create_agent.py
```

## Repository Structure

```
azure-ai-foundry-apim-integration/
├── README.md                           # This file
├── docs/
│   └── INTEGRATION-GUIDE.md           # Detailed documentation
├── 01-apim-setup/
│   ├── README.md                      # APIM setup instructions
│   ├── setup-apim.ps1                 # PowerShell script for APIM setup
│   └── policies/
│       ├── list-deployments.xml       # Policy for ListDeployments
│       ├── get-deployment.xml         # Policy for GetDeployment
│       └── chat-completions.xml       # Policy for ChatCompletions
├── 02-foundry-connection/
│   ├── README.md                      # Connection setup instructions
│   ├── connection.bicep               # Bicep template
│   └── parameters.example.json        # Example parameters
├── 03-agent-samples/
    ├── README.md                      # Sample usage instructions
    ├── pyproject.toml                 # Python dependencies (uv)
    ├── create_agent.py                # Create an agent
    ├── chat_with_agent.py             # Interactive chat
    └── test_connection.py             # Test the connection
```

## Documentation

See [docs/INTEGRATION-GUIDE.md](docs/INTEGRATION-GUIDE.md) for detailed step-by-step instructions.

## Additional Resources

- [Bring your own AI gateway (Microsoft Learn)](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/tools/bring-your-own-ai-gateway)
- [Foundry Samples - APIM Integration](https://github.com/azure-ai-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/01-connections)
- [Azure API Management documentation](https://learn.microsoft.com/en-us/azure/api-management/)

## License

MIT License - See [LICENSE](LICENSE) for details.
