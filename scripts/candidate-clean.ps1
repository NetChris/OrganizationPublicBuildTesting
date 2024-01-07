# Candidate script cleanup

. ./candidate-variables.ps1

az identity delete `
  --subscription $Subscription `
  --resource-group $ResourceGroup `
  --name $GitHubManagedIdentityName

az group delete `
  --subscription $Subscription `
  --name $ResourceGroup `
  --yes
