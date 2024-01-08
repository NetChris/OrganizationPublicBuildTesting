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

function Create-ResourceGroup {

  param (
        [Parameter(Mandatory)] [string]$Subscription,
        [Parameter(Mandatory)] [string]$Environment
    )

  az group create `
    --location westus2 `
    --subscription $Subscription `
    --tags `
      "netchris-app-aggregate=$AppAggregate" `
      "netchris-app-aggregate-short=$AppAggregateShort" `
      "netchris-app-component=github-identity" `
      "netchris-app-component-short=ghid" `
      "netchris-app-environment=$Environment" `
    --name $ResourceGroup

  "Created resource group $ResourceGroup in $Environment"

}

Create-ResourceGroup -Subscription $env:SubscriptionTesting -Environment test
Create-ResourceGroup -Subscription $env:SubscriptionMain -Environment production

# TODO - Rename ManagedIdentityObjectId to GitHubManagedIdentityObjectId
$ManagedIdentityObjectId = $(az identity create `
  --location westus2 `
  --query principalId -o tsv `
  --subscription $Subscription `
  --resource-group $CrossCuttingResourceGroup `
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
    --resource-group $ResourceGroup `
    --environment $ContainerAppEnvironment `
    --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest `
    --min-replicas 0 `
    --max-replicas 1 `
    --target-port 80 `
    --system-assigned `
    --tags `
      "netchris-app-aggregate=$AppAggregate" `
      "netchris-app-aggregate-short=$AppAggregateShort" `
      "netchris-app-component=$AppComponent" `
      "netchris-app-component-short=$AppComponent" `
    --ingress external

  $ContainerAppSystemAssignedIdentityClientId = $(az containerapp identity show `
    --query principalId -o tsv `
    --subscription $Subscription `
    --name $ContainerAppName `
    --resource-group $ResourceGroup
  )

  "ContainerAppSystemAssignedIdentityClientId: $ContainerAppSystemAssignedIdentityClientId"

  # This might warn about "System identity is already assigned to containerapp" but that's OK
  az containerapp registry set `
    --subscription $Subscription `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --identity system `
    --server $ContainerRegistryServer

  Assign-AcrPull-Role `
    -AssigneeObjectId $ContainerAppSystemAssignedIdentityClientId `
    -AcrName $ContainerRegistryServer `
    -AcrSubscription $Subscription
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


# TODO - Make sure to indicate the appropriate account/subscription and resource-group in the az call
# GitHub ops
# Get the client id and set the secret
gh secret set AZURE_CLIENT_ID -b $ManagedIdentityClientId

# TODO - Make sure to indicate the appropriate account/subscription and resource-group in the az call
# Get the tenant id and set the secret
gh secret set AZURE_TENANT_ID -b $ManagedIdentityTenantId

# TODO - Make sure to indicate the appropriate account/subscription and resource-group in the az call
# Get the subscription id and set the secret
# Note, this must be a subscription where the managed identity has an role assignment.  It's unclear if it has to be the subscription
# for the resources we're actually accessing.
gh secret set AZURE_SUBSCRIPTION_ID -b $SubscriptionSandbox

gh secret set ACR_LOGIN_SERVER -b $AcrLoginServer
