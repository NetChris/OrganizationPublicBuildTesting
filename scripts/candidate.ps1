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

"Created managed identity $ManagedIdentityObjectId"

$ManagedIdentityClientId = $(az identity show --subscription $Subscription --resource-group $ResourceGroup --name $GitHubManagedIdentityName --query clientId -o tsv)
$ManagedIdentityTenantId = $(az identity show --subscription $Subscription --resource-group $ResourceGroup --name $GitHubManagedIdentityName --query tenantId -o tsv)

"ManagedIdentityClientId: $ManagedIdentityClientId"
"ManagedIdentityTenantId: $ManagedIdentityTenantId"
