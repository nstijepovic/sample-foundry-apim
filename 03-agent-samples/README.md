# Agent Samples

Sample Python scripts for using Azure AI Foundry with your APIM connection.

## Setup

1. Install dependencies:

```bash
pip install -r requirements.txt
```

2. Set environment variables (or update the scripts):

```bash
export AZURE_AI_PROJECT_ENDPOINT="https://<account>.services.ai.azure.com/api/projects/<project>"
export AZURE_AI_CONNECTION_NAME="compass-connection"
export AZURE_AI_MODEL_NAME="gpt-5"
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
python test_connection.py
```

### Create Agent

```bash
python create_agent.py
```

### Interactive Chat

```bash
python chat_with_agent.py
```

## Model Reference

When creating agents, reference models as:

```python
model = "compass-connection/gpt-5"
```

Format: `<connection-name>/<deployment-name>`
