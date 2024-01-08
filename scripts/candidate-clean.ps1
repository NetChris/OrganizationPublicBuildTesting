# Candidate script cleanup

. ./candidate-variables.ps1

function Delete-ContainerApp {

  param (
        [Parameter(Mandatory)] [string]$AppComponent,
        [Parameter(Mandatory)] [string]$Subscription
    )

  # TODO - To function
  $ContainerAppName="$AppAggregate-$AppComponent"

  az containerapp delete `
    --yes `
    --no-wait `
    --subscription $Subscription `
    --resource-group $CrossCuttingResourceGroup `
    --name $ContainerAppName
}

function Delete-ContainerApp-Pair {

  param (
        [Parameter(Mandatory)] [string]$ContainerAppEnvironment,
        [Parameter(Mandatory)] [string]$Subscription
    )
  
  Delete-ContainerApp -Subscription $Subscription -AppComponent api
  Delete-ContainerApp -Subscription $Subscription -AppComponent app
}

Delete-ContainerApp-Pair -Subscription $env:SubscriptionTesting -ContainerAppEnvironment Test
Delete-ContainerApp-Pair -Subscription $env:SubscriptionMain -ContainerAppEnvironment Production


az identity delete `
  --subscription $Subscription `
  --resource-group $ResourceGroup `
  --name $GitHubManagedIdentityName

az group delete `
  --subscription $Subscription `
  --name $ResourceGroup `
  --yes
