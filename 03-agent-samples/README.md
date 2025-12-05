# Agent Samples

Sample Python scripts for using Azure AI Foundry Agents with APIM-proxied LLM endpoints.

## Prerequisites

- Python 3.12+
- [uv](https://docs.astral.sh/uv/) package manager
- Azure CLI logged in (`az login`)

## Setup

1. Install dependencies:

```bash
uv sync
```

2. Copy `.env.example` to `.env` and update values:

```bash
cp .env.example .env
```

3. Set your environment variables in `.env`:

```env
AZURE_AI_PROJECT_ENDPOINT=https://<account>.services.ai.azure.com/api/projects/<project>
AZURE_AI_CONNECTION_NAME=compass-connection
AZURE_AI_MODEL_NAME=gpt-5
```

## Scripts

| Script | Purpose |
|--------|---------|
| `test_connection.py` | Verify the connection works |
| `create_agent.py` | Create a simple agent |
| `chat_with_agent.py` | Interactive chat with an agent |

## Usage

### Test Connection

```bash
uv run test_connection.py
```

### Create Agent

```bash
uv run create_agent.py
```

### Interactive Chat

```bash
uv run chat_with_agent.py
```

## Model Reference

When creating agents, reference models as:

```python
model = "compass-connection/gpt-5"
```

Format: `<connection-name>/<deployment-name>`
