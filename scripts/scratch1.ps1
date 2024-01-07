# TODO - Set these in env
$SubscriptionTesting = $env:SubscriptionTesting
$SubscriptionSandbox = $env:SubscriptionSandbox
$SubscriptionMain = $env:SubscriptionMain
$AcrName = "netchrissandbox"
$ManagedIdentityName = "GitHub-NetChris-PublicBuildTesting"

# Set the GitHub repository name in the format: pauldotyu/osinfo
$GitHubRepo = "NetChris/PublicBuildTesting"

$AcrResourceId = $(az acr show --subscription $SubscriptionSandbox --name $AcrName --query "id" -o tsv)
"ACR Resource Id: $AcrResourceId"
$AcrLoginServer = $(az acr show --subscription $SubscriptionSandbox --name $AcrName --query "loginServer" -o tsv)
"ACR LoginServer: $AcrLoginServer"
$CurrentSubscriptionId = $(az account show --query id -o tsv)
"Current Subscription Id: $CurrentSubscriptionId"

# Set the resource group name
$ResourceGroup = "Sandbox"

# Establish a trust relationship between Azure and GitHub Actions
# Set the federated credential name
$FederatedCredentialName = "$ManagedIdentityName-FC"

# Set the GitHub branch name
$GitHubBranch = "building-and-testing-dotnet"

# Create the managed identity and return the service principal object id
$ManagedIdentityObjectId = $(az identity create --subscription $SubscriptionSandbox --resource-group $ResourceGroup --name $ManagedIdentityName --tags "netchris-app-aggregate=xx xx" "netchris-app-aggregate-other=yy yy" --query principalId -o tsv)
$ManagedIdentityClientId = $(az identity show   --subscription $SubscriptionSandbox --resource-group $ResourceGroup --name $ManagedIdentityName --query clientId    -o tsv)
$ManagedIdentityTenantId = $(az identity show   --subscription $SubscriptionSandbox --resource-group $ResourceGroup --name $ManagedIdentityName --query tenantId    -o tsv)

"Managed Identity ObjectId: $ManagedIdentityObjectId"
"Managed Identity ClientId: $ManagedIdentityClientId"
"Managed Identity TenantId: $ManagedIdentityTenantId"

# Grant the managed identity access to ACR resource
az role assignment create --role "AcrPush" --assignee-object-id $ManagedIdentityObjectId --assignee-principal-type ServicePrincipal --scope $AcrResourceId

# TODO - Grant access to deploy to container app
# TODO - One-time - grant access for container app to pull from ACR

# TODO - I *think* there will be a FC required for each context in the repo which will need to talk to GH:
# - main branch
# - Each well-known branch?
# - "Deployment" credentials for each deployment environment
# See https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#example-subject-claims
# See https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure
# Create the federated credential
az identity federated-credential create `
  --subscription $SubscriptionSandbox `
  --name "${FederatedCredentialName}" `
  --identity-name "${ManagedIdentityName}" `
  --resource-group "${ResourceGroup}" `
  --issuer https://token.actions.githubusercontent.com `
  --subject repo:${GitHubRepo}:ref:refs/heads/${GitHubBranch}

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
