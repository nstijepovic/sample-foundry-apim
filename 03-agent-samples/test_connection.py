"""
Test Connection

Verifies that the APIM connection is properly configured in Azure AI Foundry.
Lists available connections and tests the model.
"""

import os
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential, InteractiveBrowserCredential
from azure.ai.projects import AIProjectClient

load_dotenv()

# Configuration
PROJECT_ENDPOINT = os.environ.get(
    "AZURE_AI_PROJECT_ENDPOINT",
    "https://<account>.services.ai.azure.com/api/projects/<project>"
)
CONNECTION_NAME = os.environ.get("AZURE_AI_CONNECTION_NAME", "compass-connection")
MODEL_NAME = os.environ.get("AZURE_AI_MODEL_NAME", "gpt-5")

# Optional: Set tenant ID if using InteractiveBrowserCredential
TENANT_ID = os.environ.get("AZURE_TENANT_ID", None)


def get_credential():
    """Get Azure credential."""
    if TENANT_ID:
        return InteractiveBrowserCredential(tenant_id=TENANT_ID)
    return DefaultAzureCredential()


def main():
    print("=" * 60)
    print("Testing Azure AI Foundry Connection")
    print("=" * 60)
    print(f"\nProject: {PROJECT_ENDPOINT}")
    print(f"Connection: {CONNECTION_NAME}")
    print(f"Model: {MODEL_NAME}")
    print()

    # Connect to Foundry
    credential = get_credential()
    client = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=credential)

    # List connections
    print("Connections:")
    print("-" * 40)
    found_connection = False
    for conn in client.connections.list():
        category = getattr(conn.properties, 'category', 'Unknown')
        target = getattr(conn.properties, 'target', 'N/A')
        print(f"  • {conn.name}")
        print(f"    Category: {category}")
        print(f"    Target: {target}")
        print()
        if conn.name == CONNECTION_NAME:
            found_connection = True

    if not found_connection:
        print(f"⚠️  Connection '{CONNECTION_NAME}' not found!")
        print("   Make sure to deploy the connection using 02-foundry-connection/")
        return

    # Test the model
    print("-" * 40)
    print(f"Testing model: {CONNECTION_NAME}/{MODEL_NAME}")
    print("-" * 40)

    openai = client.get_openai_client()
    
    response = openai.chat.completions.create(
        model=f"{CONNECTION_NAME}/{MODEL_NAME}",
        messages=[
            {"role": "user", "content": "Say 'Connection test successful!' and nothing else."}
        ],
        max_tokens=50
    )

    result = response.choices[0].message.content
    print(f"\nResponse: {result}")
    
    if "successful" in result.lower():
        print("\n✅ Connection test PASSED!")
    else:
        print("\n✅ Got response from model (connection works)")


if __name__ == "__main__":
    main()
