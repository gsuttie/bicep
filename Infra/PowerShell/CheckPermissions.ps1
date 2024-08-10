function CheckPermissions {
    Write-Host "Checking you have the right Az CLI extensions installed." -ForegroundColor Blue
    # This section of code will check of extensions and install if they are missing.
    $extensionList = @(
        "account"
        "aks-preview"
        "azure-devops"
        "azure-firewall"
        "front-door"
        "application-insights"
    ) # Add extensions to this list to have the script check for them and install them if they are missing.

    foreach ($extension in $extensionList)
    {
    $extensionCheck = az extension list
    if ($extensionCheck -like "*$extension*")
    {
    Write-Host "You have the $extension extension installed already."  -ForegroundColor Green
    }
    else
    {
    Write-Host "You do not have the required $extension extension. We will install it now." -ForegroundColor Red
    az extension add -n $extension
    }
    }
    Write-Host "Checking you have the right permissons to deploy the resources..." -ForegroundColor Blue
    $user = az ad signed-in-user show --query id -o tsv
    $subid = az account show --query id -o tsv
    $cspCheck = az account subscription show --id $subid --query subscriptionPolicies.quotaId -o tsv
    if ($cspCheck -like "*CSP*")
    {
    $userperms = az role assignment list --assignee $user --include-inherited --output json --query '[].{roleDefinitionName:roleDefinitionName}' | convertFrom-Json
    if ($userperms.roleDefinitionName -contains 'Owner' -or $userperms.roleDefinitionName -contains 'Contributor' -or $userperms.roleDefinitionName -like 'CoAdministrator')
    {
    Write-host "  You have the correct permissions." -ForegroundColor Green
    }
    else
    {
    Write-Host "  You do not have the correct permissions to create the resources. Please make sure you have contributer permissions on the subscription." -ForegroundColor Red
    break
    }
    }
    else
    {
    $userperms = az role assignment list --assignee $user --include-classic-administrators --include-inherited --output json --query '[].{roleDefinitionName:roleDefinitionName}' | convertFrom-Json
    if ($userperms.roleDefinitionName -contains 'Owner' -or $userperms.roleDefinitionName -contains 'Contributor' -or $userperms.roleDefinitionName -like 'CoAdministrator')
    {
    Write-host "  You have the correct permissions." -ForegroundColor Green
    }
    else
    {
    Write-Host "  You do not have the correct permissions to create the resources. Please make sure you have contributer permissions on the subscription." -ForegroundColor Red
    break
    }
    }
}