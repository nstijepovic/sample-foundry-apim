<#
.SYNOPSIS
    Set up Azure API Management for Azure AI Foundry integration.

.DESCRIPTION
    ⚠️  THIS IS A REFERENCE SCRIPT - RUN STEPS SEPARATELY!
    
    Due to potential network issues (Bad Gateway, timeouts), run each step 
    individually in your terminal rather than executing the full script.
    
    Copy and paste each section one at a time.

.NOTES
    Key configuration points:
    - Uses 'api-key' as the subscription header (REQUIRED for Foundry compatibility)
    - GetDeployment uses static response (C# expressions cause validation issues via az rest)
    - Policies are applied via az rest with JSON files

.EXAMPLE
    # Step 1: Update the CONFIGURATION section below with your values
    # Step 2: Copy each step section and run in terminal separately
#>

# =============================================================================
# CONFIGURATION - Update these values first!
# =============================================================================

$SubscriptionId = "YOUR_SUBSCRIPTION_ID"
$ResourceGroup = "YOUR_RESOURCE_GROUP"
$ApimName = "YOUR_APIM_NAME"
$ApiId = "compass-api"
$ApiPath = "compass"
$BackendUrl = "https://api.core42.ai/openai"
$ExternalApiKey = "YOUR_EXTERNAL_LLM_API_KEY"
$Models = @("gpt-4.1", "gpt-5")

# =============================================================================
# STEP 1: Set subscription
# =============================================================================

az account set --subscription $SubscriptionId

# =============================================================================
# STEP 2: Create API
# IMPORTANT: --subscription-key-header-name "api-key" is REQUIRED for Foundry!
# =============================================================================

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

# =============================================================================
# STEP 3: Create Operations (run each separately if errors occur)
# =============================================================================

# 3a. ListDeployments
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --operation-id ListDeployments `
    --display-name "ListDeployments" `
    --method GET `
    --url-template "/deployments"

# 3b. GetDeployment
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --operation-id GetDeployment `
    --display-name "GetDeployment" `
    --method GET `
    --url-template "/deployments/{deploymentName}" `
    --template-parameters name=deploymentName type=string required=true

# 3c. ChatCompletions
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --operation-id ChatCompletions `
    --display-name "ChatCompletions" `
    --method POST `
    --url-template "/deployments/{deployment-id}/chat/completions" `
    --template-parameters name=deployment-id type=string required=true

# =============================================================================
# STEP 4: Apply Policies
# Each policy is applied via az rest with a JSON file
# =============================================================================

$baseUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/apis/$ApiId"

# --- 4a. ListDeployments Policy ---
# Update model names in the JSON to match your models
$listPolicy = @{
    properties = @{
        format = "rawxml"
        value = '<policies><inbound><base /><return-response><set-status code="200" reason="OK" /><set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header><set-body>{"value":[{"name":"gpt-4.1","properties":{"model":{"format":"OpenAI","name":"gpt-4.1","version":""}}},{"name":"gpt-5","properties":{"model":{"format":"OpenAI","name":"gpt-5","version":""}}}]}</set-body></return-response></inbound><backend><base /></backend><outbound><base /></outbound></policies>'
    }
} | ConvertTo-Json -Depth 5
$listPolicy | Out-File -FilePath "list-policy.json" -Encoding UTF8

az rest --method PUT --uri "$baseUri/operations/ListDeployments/policies/policy?api-version=2022-08-01" --body "@list-policy.json"

# --- 4b. GetDeployment Policy (static response) ---
$getPolicy = @{
    properties = @{
        format = "rawxml"
        value = '<policies><inbound><base /><return-response><set-status code="200" reason="OK" /><set-header name="Content-Type" exists-action="override"><value>application/json</value></set-header><set-body>{"name": "gpt-5", "properties": {"model": {"format": "OpenAI", "name": "gpt-5", "version": ""}}}</set-body></return-response></inbound><backend><base /></backend><outbound><base /></outbound></policies>'
    }
} | ConvertTo-Json -Depth 5
$getPolicy | Out-File -FilePath "get-policy.json" -Encoding UTF8

az rest --method PUT --uri "$baseUri/operations/GetDeployment/policies/policy?api-version=2022-08-01" --body "@get-policy.json"

# --- 4c. ChatCompletions Policy ---
$chatPolicy = @{
    properties = @{
        format = "rawxml"
        value = "<policies><inbound><base /><set-backend-service base-url=`"$BackendUrl`" /><set-header name=`"api-key`" exists-action=`"override`"><value>$ExternalApiKey</value></set-header></inbound><backend><base /></backend><outbound><base /></outbound></policies>"
    }
} | ConvertTo-Json -Depth 5
$chatPolicy | Out-File -FilePath "chat-policy.json" -Encoding UTF8

az rest --method PUT --uri "$baseUri/operations/ChatCompletions/policies/policy?api-version=2022-08-01" --body "@chat-policy.json"

# =============================================================================
# STEP 5: Test the endpoints
# =============================================================================

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

# =============================================================================
# DONE! Next: Deploy the Foundry connection using 02-foundry-connection/
# =============================================================================
