"""
Chat with Agent

Interactive chat session with an agent in Azure AI Foundry.
"""

import os
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential, InteractiveBrowserCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import AgentReference

load_dotenv()

# Configuration
PROJECT_ENDPOINT = os.environ.get(
    "AZURE_AI_PROJECT_ENDPOINT",
    "https://<account>.services.ai.azure.com/api/projects/<project>"
)
AGENT_NAME = os.environ.get("AZURE_AI_AGENT_NAME", "my-compass-agent")
TENANT_ID = os.environ.get("AZURE_TENANT_ID", None)


def get_credential():
    """Get Azure credential."""
    if TENANT_ID:
        return InteractiveBrowserCredential(tenant_id=TENANT_ID)
    return DefaultAzureCredential()


def main():
    print("=" * 60)
    print("Chat with Agent")
    print("=" * 60)
    print(f"\nProject: {PROJECT_ENDPOINT}")
    print(f"Agent: {AGENT_NAME}")
    print("\nType 'exit' to quit.\n")
    print("-" * 60)

    # Connect to Foundry
    credential = get_credential()
    client = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=credential)
    openai = client.get_openai_client()

    # Create conversation
    conversation = openai.conversations.create()
    print(f"Conversation: {conversation.id}\n")

    try:
        while True:
            # Get user input
            user_input = input("You: ").strip()
            if not user_input:
                continue
            if user_input.lower() in ["exit", "quit"]:
                break

            # Send message to agent
            response = openai.responses.create(
                conversation=conversation.id,
                extra_body={
                    "agent": AgentReference(name=AGENT_NAME).as_dict()
                },
                input=user_input,
            )

            # Print response
            print(f"\nAgent: {response.output_text}\n")

    except KeyboardInterrupt:
        print("\n\nInterrupted!")

    finally:
        # Clean up
        try:
            openai.conversations.delete(conversation_id=conversation.id)
            print(f"\nConversation {conversation.id} deleted.")
        except Exception as e:
            print(f"\nNote: Could not delete conversation: {e}")


if __name__ == "__main__":
    main()
