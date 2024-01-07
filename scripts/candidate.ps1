# Candidate script
# Requirements:
# - .NET API app, deployed, repeatable
# - .NET Web app, deployed, repeatable
# Assumed existing resources:
# - GitHub repo for both
# - Container registry
# Plan:
# - Create resource group for app aggregate
# - Create managed identity for the GitHub Repo:
#   - xxx
#   - xxx
#   - xxx
#   - xxx
#   - xxx
# - Grant the GitHub Action identity push access to the registry
#   - xxx
#   - xxx
#   - xxx
# - Create a container app
# - XXX
# - XXX
# - XXX
# - XXX
# - XXX
# - XXX

. ./candidate-variables.ps1

az group create `
  --location westus2 `
  --subscription $Subscription `
  --tags `
    "netchris-app-aggregate=$AppAggregate" `
    "netchris-app-aggregate-short=$AppAggregateShort" `
    "netchris-app-component=github-identity" `
    "netchris-app-component-short=ghid" `
  --name $ResourceGroup

"Created resource group $ResourceGroup"

# TODO - Rename ManagedIdentityObjectId to GitHubManagedIdentityObjectId
$ManagedIdentityObjectId = $(az identity create `
  --location westus2 `
  --query principalId -o tsv `
  --subscription $Subscription `
  --resource-group $ResourceGroup `
  --name $GitHubManagedIdentityName `
  --tags `
    "netchris-app-aggregate=$AppAggregate" `
    "netchris-app-aggregate-short=$AppAggregateShort" `
    "netchris-app-component=github-identity" `
    "netchris-app-component-short=ghid" `
  )

"GitHubManagedIdentityObjectId: $ManagedIdentityObjectId"

# TODO - Rename ManagedIdentityClientId to GitHubManagedIdentityClientId
$ManagedIdentityClientId = $(az identity show --subscription $Subscription --resource-group $ResourceGroup --name $GitHubManagedIdentityName --query clientId -o tsv)
# TODO - Rename ManagedIdentityTenantId to GitHubManagedIdentityTenantId
$ManagedIdentityTenantId = $(az identity show --subscription $Subscription --resource-group $ResourceGroup --name $GitHubManagedIdentityName --query tenantId -o tsv)

"GitHubManagedIdentityClientId: $ManagedIdentityClientId"
"GitHubManagedIdentityTenantId: $ManagedIdentityTenantId"

function Assign-AcrPush-Role {

  param (
        [Parameter(Mandatory)] [string]$AcrName,
        [Parameter(Mandatory)] [string]$AcrSubscription
    )
  
  $AcrResourceId=$(az acr show --subscription $AcrSubscription --name $AcrName --query id -o tsv)

  # Grant the GitHub managed identity access to test ACR resource
  az role assignment create `
    --role "AcrPush" `
    --assignee-object-id $ManagedIdentityObjectId `
    --assignee-principal-type ServicePrincipal `
    --scope $AcrResourceId
}

Assign-AcrPush-Role -AcrName netchris -AcrSubscription $env:SubscriptionMain
Assign-AcrPush-Role -AcrName netchristest -AcrSubscription $env:SubscriptionTesting
Assign-AcrPush-Role -AcrName netchrissandbox -AcrSubscription $env:SubscriptionSandbox
