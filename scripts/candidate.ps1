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

function Assign-AcrPull-Role {

  param (
        [Parameter(Mandatory)] [string]$AssigneeObjectId,
        [Parameter(Mandatory)] [string]$AcrName,
        [Parameter(Mandatory)] [string]$AcrSubscription
    )
  
  $AcrResourceId=$(az acr show --subscription $AcrSubscription --name $AcrName --query id -o tsv)

  az role assignment create `
    --role "AcrPull" `
    --assignee-object-id $AssigneeObjectId `
    --assignee-principal-type ServicePrincipal `
    --scope $AcrResourceId
}

function Create-ContainerApp {

  param (
        [Parameter(Mandatory)] [string]$ContainerAppEnvironment,
        [Parameter(Mandatory)] [string]$AppComponent,
        [Parameter(Mandatory)] [string]$AppComponentShort,
        [Parameter(Mandatory)] [string]$Subscription,
        [Parameter(Mandatory)] [string]$ContainerRegistryServer
    )

  # TODO - To function
  $ContainerAppName="$AppAggregate-$AppComponent"

  # TODO - Tags
  az containerapp create `
    --subscription $Subscription `
    --name $ContainerAppName `
    --resource-group $CrossCuttingResourceGroup `
    --environment $ContainerAppEnvironment `
    --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest `
    --min-replicas 0 `
    --max-replicas 1 `
    --target-port 80 `
    --tags `
      "netchris-app-aggregate=$AppAggregate" `
      "netchris-app-aggregate-short=$AppAggregateShort" `
      "netchris-app-component=$AppComponent" `
      "netchris-app-component-short=$AppComponent" `
    --ingress external

  $ContainerAppSystemAssignedIdentityClientId = $(az containerapp identity assign `
    --query principalId -o tsv `
    --subscription $Subscription `
    --name $ContainerAppName `
    --resource-group $CrossCuttingResourceGroup `
    --system-assigned `
  )

  "ContainerAppSystemAssignedIdentityClientId: $ContainerAppSystemAssignedIdentityClientId"

  Assign-AcrPull-Role `
    -AssigneeObjectId $ContainerAppSystemAssignedIdentityClientId `
    -AcrName $ContainerRegistryServer `
    -AcrSubscription $Subscription

  az containerapp registry set `
    --subscription $Subscription `
    --name $ContainerAppName `
    --resource-group $CrossCuttingResourceGroup `
    --identity system `
    --server $ContainerRegistryServer
}

function Create-ContainerApp-Pair {

  param (
        [Parameter(Mandatory)] [string]$ContainerAppEnvironment,
        [Parameter(Mandatory)] [string]$Subscription,
        [Parameter(Mandatory)] [string]$ContainerRegistryServer
    )
  
  Create-ContainerApp `
    -Subscription $Subscription `
    -ContainerAppEnvironment $ContainerAppEnvironment `
    -ContainerRegistryServer $ContainerRegistryServer `
    -AppComponent api `
    -AppComponentShort api

  Create-ContainerApp `
    -Subscription $Subscription `
    -ContainerAppEnvironment $ContainerAppEnvironment `
    -ContainerRegistryServer $ContainerRegistryServer `
    -AppComponent app `
    -AppComponentShort app
}

Create-ContainerApp-Pair -Subscription $env:SubscriptionTesting -ContainerAppEnvironment Test -ContainerRegistryServer "netchristest.azurecr.io"
Create-ContainerApp-Pair -Subscription $env:SubscriptionMain -ContainerAppEnvironment Production -ContainerRegistryServer "netchris.azurecr.io"
