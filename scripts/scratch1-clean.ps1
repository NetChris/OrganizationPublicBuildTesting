$SubscriptionTesting = $env:SubscriptionTesting
$SubscriptionSandbox = $env:SubscriptionSandbox
$SubscriptionMain = $env:SubscriptionMain

# Set the resource group name
$ResourceGroup = "Sandbox"

# Set the managed identity name
$ManagedIdentityName = "GitHub-NetChris-PublicBuildTesting"

# Set the GitHub repository name in the format: pauldotyu/osinfo
$GitHubRepo = "NetChris/PublicBuildTesting"

# Set the GitHub branch name
$GitHubBranch = "building-and-testing-dotnet"

"Deleting GitHub secrets ..."
gh secret delete AZURE_CLIENT_ID
gh secret delete AZURE_TENANT_ID
gh secret delete AZURE_SUBSCRIPTION_ID
gh secret delete ACR_LOGIN_SERVER_TEST
gh secret delete ACR_LOGIN_SERVER_PRODUCTION

"Deleting managed identity $ManagedIdentityName ..."
az identity delete -n $ManagedIdentityName --subscription $SubscriptionSandbox --resource-group $ResourceGroup
