"""
Test Connection

Verifies that the APIM connection is properly configured in Azure AI Foundry.
Lists available connections and tests the model.
"""

import os
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient

load_dotenv()

# Configuration
PROJECT_ENDPOINT = os.environ.get(
    "AZURE_AI_PROJECT_ENDPOINT",
    "https://<account>.services.ai.azure.com/api/projects/<project>"
)
CONNECTION_NAME = os.environ.get("AZURE_AI_CONNECTION_NAME", "compass-connection")
MODEL_NAME = os.environ.get("AZURE_AI_MODEL_NAME", "gpt-5")


def main():
    print("=" * 60)
    print("Testing Azure AI Foundry Connection")
    print("=" * 60)
    print(f"\nProject: {PROJECT_ENDPOINT}")
    print(f"Connection: {CONNECTION_NAME}")
    print(f"Model: {MODEL_NAME}")
    print()

    # Connect to Foundry using DefaultAzureCredential (uses az login session)
    credential = DefaultAzureCredential()
    client = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=credential)

    # List connections
    print("Connections:")
    print("-" * 40)
    found_connection = False
    for conn in client.connections.list():
        print(f"  • {conn.name}")
        if hasattr(conn, 'properties'):
            category = getattr(conn.properties, 'category', 'Unknown')
            target = getattr(conn.properties, 'target', 'N/A')
            print(f"    Category: {category}")
            print(f"    Target: {target}")
        print()
        if conn.name == CONNECTION_NAME:
            found_connection = True

    if not found_connection:
        print(f"⚠️  Connection '{CONNECTION_NAME}' not found!")
        print("   Make sure to deploy the connection using 02-foundry-connection/")
        return

    # Test the model by creating a simple agent
    print("-" * 40)
    print(f"Testing model: {CONNECTION_NAME}/{MODEL_NAME}")
    print("-" * 40)

    from azure.ai.projects.models import PromptAgentDefinition

    # Create a test agent
    print("\nCreating test agent...")
    agent = client.agents.create_version(
        agent_name="connection-test-agent",
        definition=PromptAgentDefinition(
            model=f"{CONNECTION_NAME}/{MODEL_NAME}",
            instructions="You are a test agent. Always respond with exactly: 'Connection test successful!'"
        )
    )
    print(f"  Agent created: {agent.name} (v{agent.version})")

    # Test the agent
    openai = client.get_openai_client()
    conversation = openai.conversations.create()
    
    print("\nSending test message...")
    response = openai.responses.create(
        conversation=conversation.id,
        extra_body={
            "agent": {"name": agent.name, "type": "agent_reference"}
        },
        input="Say hello"
    )

    result = response.output_text
    print(f"\nResponse: {result}")
    
    # Cleanup
    openai.conversations.delete(conversation_id=conversation.id)
    client.agents.delete_version(agent_name=agent.name, agent_version=agent.version)
    print("\n✅ Connection test PASSED! Agent created and responded.")


if __name__ == "__main__":
    main()
