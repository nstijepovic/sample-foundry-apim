<#
.SYNOPSIS
    Set up Azure API Management for Azure AI Foundry integration.

.DESCRIPTION
    This script creates an API in APIM with the required operations and policies
    to work with Azure AI Foundry's ApiManagement connection type.

.PARAMETER SubscriptionId
    Azure subscription ID.

.PARAMETER ResourceGroup
    Resource group containing the APIM instance.

.PARAMETER ApimName
    Name of the APIM instance.

.PARAMETER ApiId
    ID for the API (default: compass-api).

.PARAMETER ApiPath
    URL path for the API (default: compass).

.PARAMETER BackendUrl
    Backend URL for the external LLM provider.

.PARAMETER ExternalApiKey
    API key for the external LLM provider.

.PARAMETER Models
    Array of model names to expose (default: gpt-4.1, gpt-5).

.EXAMPLE
    ./setup-apim.ps1 -SubscriptionId "xxx" -ResourceGroup "my-rg" -ApimName "my-apim" `
      -BackendUrl "https://api.core42.ai/openai" -ExternalApiKey "xxx" -Models @("gpt-4.1", "gpt-5")
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$ApimName,

    [string]$ApiId = "compass-api",

    [string]$ApiPath = "compass",

    [Parameter(Mandatory=$true)]
    [string]$BackendUrl,

    [Parameter(Mandatory=$true)]
    [string]$ExternalApiKey,

    [string[]]$Models = @("gpt-4.1", "gpt-5")
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Azure API Management Setup for AI Foundry" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Subscription: $SubscriptionId"
Write-Host "Resource Group: $ResourceGroup"
Write-Host "APIM Name: $ApimName"
Write-Host "API ID: $ApiId"
Write-Host "Backend URL: $BackendUrl"
Write-Host "Models: $($Models -join ', ')"
Write-Host ""

# Set subscription
Write-Host "Setting subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Step 1: Create API
Write-Host ""
Write-Host "Step 1: Creating API..." -ForegroundColor Yellow
az apim api create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --display-name "Compass API" `
    --path $ApiPath `
    --service-url $BackendUrl `
    --protocols https `
    --subscription-required true

# Step 2: Create Operations
Write-Host ""
Write-Host "Step 2: Creating operations..." -ForegroundColor Yellow

# ListDeployments
Write-Host "  Creating ListDeployments..."
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --operation-id ListDeployments `
    --display-name "ListDeployments" `
    --method GET `
    --url-template "/deployments"

# GetDeployment
Write-Host "  Creating GetDeployment..."
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --operation-id GetDeployment `
    --display-name "GetDeployment" `
    --method GET `
    --url-template "/deployments/{deploymentName}" `
    --template-parameters name=deploymentName type=string required=true

# ChatCompletions
Write-Host "  Creating ChatCompletions..."
az apim api operation create `
    --resource-group $ResourceGroup `
    --service-name $ApimName `
    --api-id $ApiId `
    --operation-id ChatCompletions `
    --display-name "ChatCompletions" `
    --method POST `
    --url-template "/deployments/{deployment-id}/chat/completions" `
    --template-parameters name=deployment-id type=string required=true

# Step 3: Apply Policies
Write-Host ""
Write-Host "Step 3: Applying policies..." -ForegroundColor Yellow

$baseUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ApiManagement/service/$ApimName/apis/$ApiId"

# Generate model list for ListDeployments policy
$modelList = ($Models | ForEach-Object {
    @"
        {
            "name": "$_",
            "properties": {
                "model": {
                    "format": "OpenAI",
                    "name": "$_",
                    "version": ""
                }
            }
        }
"@
}) -join ",`n"

# ListDeployments policy
$listDeploymentsPolicy = @"
<policies>
    <inbound>
        <base />
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>{
    "value": [
$modelList
    ]
}</set-body>
        </return-response>
    </inbound>
    <backend><base /></backend>
    <outbound><base /></outbound>
    <on-error><base /></on-error>
</policies>
"@

Write-Host "  Applying ListDeployments policy..."
$listDeploymentsBody = @{
    properties = @{
        format = "xml"
        value = $listDeploymentsPolicy
    }
} | ConvertTo-Json -Depth 5

az rest --method PUT `
    --uri "$baseUri/operations/ListDeployments/policies/policy?api-version=2022-08-01" `
    --body $listDeploymentsBody

# GetDeployment policy
$getDeploymentPolicy = @"
<policies>
    <inbound>
        <base />
        <return-response>
            <set-status code="200" reason="OK" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@{
                var deploymentName = context.Request.MatchedParameters["deploymentName"];
                return "{\"name\": \"" + deploymentName + "\", \"properties\": {\"model\": {\"format\": \"OpenAI\", \"name\": \"" + deploymentName + "\", \"version\": \"\"}}}";
            }</set-body>
        </return-response>
    </inbound>
    <backend><base /></backend>
    <outbound><base /></outbound>
    <on-error><base /></on-error>
</policies>
"@

Write-Host "  Applying GetDeployment policy..."
$getDeploymentBody = @{
    properties = @{
        format = "xml"
        value = $getDeploymentPolicy
    }
} | ConvertTo-Json -Depth 5

az rest --method PUT `
    --uri "$baseUri/operations/GetDeployment/policies/policy?api-version=2022-08-01" `
    --body $getDeploymentBody

# ChatCompletions policy
$chatCompletionsPolicy = @"
<policies>
    <inbound>
        <base />
        <set-header name="api-key" exists-action="override">
            <value>$ExternalApiKey</value>
        </set-header>
    </inbound>
    <backend><base /></backend>
    <outbound><base /></outbound>
    <on-error><base /></on-error>
</policies>
"@

Write-Host "  Applying ChatCompletions policy..."
$chatCompletionsBody = @{
    properties = @{
        format = "xml"
        value = $chatCompletionsPolicy
    }
} | ConvertTo-Json -Depth 5

az rest --method PUT `
    --uri "$baseUri/operations/ChatCompletions/policies/policy?api-version=2022-08-01" `
    --body $chatCompletionsBody

# Done
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "APIM Setup Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "API Endpoint: https://$ApimName.azure-api.net/$ApiPath"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Get your APIM subscription key from Azure Portal"
Write-Host "  2. Test the endpoints using the test commands in README.md"
Write-Host "  3. Deploy the Foundry connection using 02-foundry-connection/"
