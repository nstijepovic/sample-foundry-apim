"""
Create Agent

Creates an agent in Azure AI Foundry using the APIM connection.
"""

import os
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential, InteractiveBrowserCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import PromptAgentDefinition

load_dotenv()

# Configuration
PROJECT_ENDPOINT = os.environ.get(
    "AZURE_AI_PROJECT_ENDPOINT",
    "https://<account>.services.ai.azure.com/api/projects/<project>"
)
CONNECTION_NAME = os.environ.get("AZURE_AI_CONNECTION_NAME", "compass-connection")
MODEL_NAME = os.environ.get("AZURE_AI_MODEL_NAME", "gpt-5")
TENANT_ID = os.environ.get("AZURE_TENANT_ID", None)

# Agent configuration
AGENT_NAME = "my-compass-agent"
AGENT_INSTRUCTIONS = """You are a helpful assistant powered by an external LLM through Azure API Management.

Be concise and helpful in your responses."""


def get_credential():
    """Get Azure credential."""
    if TENANT_ID:
        return InteractiveBrowserCredential(tenant_id=TENANT_ID)
    return DefaultAzureCredential()


def main():
    print("=" * 60)
    print("Creating Agent in Azure AI Foundry")
    print("=" * 60)
    print(f"\nProject: {PROJECT_ENDPOINT}")
    print(f"Model: {CONNECTION_NAME}/{MODEL_NAME}")
    print(f"Agent: {AGENT_NAME}")
    print()

    # Connect to Foundry
    credential = get_credential()
    client = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=credential)

    # Create agent
    print("Creating agent...")
    agent = client.agents.create_version(
        agent_name=AGENT_NAME,
        definition=PromptAgentDefinition(
            model=f"{CONNECTION_NAME}/{MODEL_NAME}",
            instructions=AGENT_INSTRUCTIONS,
        )
    )

    print(f"\n✅ Agent created!")
    print(f"   Name: {agent.name}")
    print(f"   Version: {agent.version}")
    print()
    print("Next steps:")
    print("  1. Test the agent with: python chat_with_agent.py")
    print("  2. Or use it in the Azure AI Foundry portal")


if __name__ == "__main__":
    main()
