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
    - GetDeployment resolves each advertised model by name and returns 404 for anything else
    - Policies live in policies/*.xml and are applied via az rest with JSON files

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
# SAMPLE ONLY: a literal key ends up in clear text in the policy and in chat-policy.json.
# Production should store it as an APIM named value backed by Key Vault and reference
# it from the policy as {{external-llm-api-key}}.
$ExternalApiKey = "YOUR_EXTERNAL_LLM_API_KEY"

# The XML files in policies/ are the source of truth - STEP 4 reads them.
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$PolicyDir = Join-Path $ScriptDir "policies"

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
# Each policy is read from policies/*.xml and applied via az rest with a JSON file.
# Edit the XML files to change a policy - do not edit the JSON.
# =============================================================================

$baseUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/apis/$ApiId"

# --- 4a. ListDeployments Policy ---
# Update model names in policies/list-deployments.xml to match your models
$listXml = Get-Content (Join-Path $PolicyDir "list-deployments.xml") -Raw
@{ properties = @{ format = "rawxml"; value = $listXml } } |
    ConvertTo-Json -Depth 5 | Out-File -FilePath "list-policy.json" -Encoding UTF8

az rest --method PUT --uri "$baseUri/operations/ListDeployments/policies/policy?api-version=2022-08-01" --body "@list-policy.json"

# --- 4b. GetDeployment Policy ---
# Every model listed by ListDeployments needs a branch in policies/get-deployment.xml
$getXml = Get-Content (Join-Path $PolicyDir "get-deployment.xml") -Raw
@{ properties = @{ format = "rawxml"; value = $getXml } } |
    ConvertTo-Json -Depth 5 | Out-File -FilePath "get-policy.json" -Encoding UTF8

az rest --method PUT --uri "$baseUri/operations/GetDeployment/policies/policy?api-version=2022-08-01" --body "@get-policy.json"

# --- 4c. ChatCompletions Policy ---
# The key stays a placeholder in the XML so the real one is never committed.
$chatXml = (Get-Content (Join-Path $PolicyDir "chat-completions.xml") -Raw).
    Replace("YOUR_BACKEND_URL", $BackendUrl).
    Replace("YOUR_EXTERNAL_LLM_API_KEY", $ExternalApiKey)
@{ properties = @{ format = "rawxml"; value = $chatXml } } |
    ConvertTo-Json -Depth 5 | Out-File -FilePath "chat-policy.json" -Encoding UTF8

az rest --method PUT --uri "$baseUri/operations/ChatCompletions/policies/policy?api-version=2022-08-01" --body "@chat-policy.json"

# --- 4d. Remove the generated policy bodies ---
# chat-policy.json holds $ExternalApiKey in clear text, so do not leave it on disk.
Remove-Item list-policy.json, get-policy.json, chat-policy.json -ErrorAction SilentlyContinue

# =============================================================================
# STEP 5: Test the endpoints
# =============================================================================

$apimKey = "YOUR_APIM_SUBSCRIPTION_KEY"  # Get from Azure Portal > APIM > Subscriptions

# Test ListDeployments
Invoke-RestMethod -Uri "https://$ApimName.azure-api.net/$ApiPath/deployments?api-version=2024-10-21" -Headers @{"api-key"=$apimKey}

# Test GetDeployment
Invoke-RestMethod -Uri "https://$ApimName.azure-api.net/$ApiPath/deployments/gpt-5?api-version=2024-10-21" -Headers @{"api-key"=$apimKey}

# Test GetDeployment for an unknown model - should return 404, not 200
Invoke-RestMethod -Uri "https://$ApimName.azure-api.net/$ApiPath/deployments/does-not-exist?api-version=2024-10-21" -Headers @{"api-key"=$apimKey}

# Test ChatCompletions
$resp = Invoke-RestMethod -Uri "https://$ApimName.azure-api.net/$ApiPath/deployments/gpt-5/chat/completions?api-version=2024-10-21" `
    -Headers @{"api-key"=$apimKey; "Content-Type"="application/json"} `
    -Method POST -Body '{"messages":[{"role":"user","content":"Hello"}]}'
$resp.choices[0].message.content

# =============================================================================
# DONE! Next: Deploy the Foundry connection using 02-foundry-connection/
# =============================================================================
