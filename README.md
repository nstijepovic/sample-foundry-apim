# Azure AI Foundry + APIM Integration

> Connect Azure AI Foundry to any OpenAI-compatible LLM provider through Azure API Management (APIM).

## Official Documentation

Before starting, review the official Microsoft documentation:

| Resource | Description |
|----------|-------------|
| [Bring your own AI gateway to Azure AI Agent Service](https://learn.microsoft.com/en-us/azure/ai-foundry/agents/how-to/tools/bring-your-own-ai-gateway) | Official guide for APIM integration with Foundry agents |
| [APIM and Model Gateway Integration Guide](https://github.com/azure-ai-foundry/foundry-samples/blob/main/infrastructure/infrastructure-setup-bicep/01-connections/apim-and-modelgateway-integration-guide.md) | Sample Bicep templates from Microsoft |
| [Azure AI Foundry Connections](https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/connections-add) | How to create and manage connections |

## Overview

This repository provides templates and scripts to:

1. **Configure APIM** as a proxy to external LLM providers (e.g., Core42 Compass, OpenAI, Anthropic)
2. **Create a Foundry Connection** that uses the APIM proxy
3. **Build Agents** in Azure AI Foundry that leverage external LLMs

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   Azure AI Foundry  │────▶│   Azure API         │────▶│   External LLM      │
│   (Agents, Tools)   │     │   Management        │     │   Provider          │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
```

## Quick Start

### Prerequisites

- Azure subscription with:
  - Azure API Management instance
  - Azure AI Foundry account and project
- External LLM API key (e.g., Core42 Compass)
- Azure CLI installed

### Step 1: Configure APIM

```powershell
cd 01-apim-setup
./setup-apim.ps1 -ResourceGroup "my-rg" -ApimName "my-apim" -BackendUrl "https://api.core42.ai/openai"
```

### Step 2: Deploy Foundry Connection

```powershell
cd ../02-foundry-connection
az deployment group create --resource-group "my-rg" --template-file connection.bicep --parameters @parameters.json
```

### Step 3: Create and Test Agent

```powershell
cd ../03-agent-samples
pip install -r requirements.txt
python create_agent.py
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
└── 03-agent-samples/
    ├── README.md                      # Sample usage instructions
    ├── requirements.txt               # Python dependencies
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
