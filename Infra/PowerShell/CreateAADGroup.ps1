function CreateAKSAADGroup($aksAADGroup) {

    Write-Host "Checking if Azure AD '$aksAADGroup' group exists..." -ForegroundColor Blue
    $groupName = az ad group show --group $aksAADGroup 
    if ($groupName -notlike "*No group matches*") {
        Write-Host "  AAD group already exists." -ForegroundColor Yellow
        $groupID = az ad group show --group $aksAADGroup --query id --output tsv
    }
    else {
        Write-Host "  AAD group doesn't exist, creating a new one..." -ForegroundColor Yellow
        az ad group create --display-name $aksAADGroup --mail-nickname $aksAADGroup --output none
        if (!$?) {
            Write-Host "  Something went wrong. Please check the error and try again." -ForegroundColor Red
            break   
        }
        Write-Host "  AAD group created." -ForegroundColor Green
        $groupID = az ad group show --group $aksAADGroup --query id --output tsv
    }

    return $groupID
}

function assignCurrentUserToGroup($aksAADGroup) {

    Write-Host "Checking if signed in user is member of Azure AD '$aksAADGroup' group..." -ForegroundColor Blue
    $groupMember = az ad group member check --group $aksAADGroup --member-id (az ad signed-in-user show --query id -o tsv) | ConvertFrom-Json
    if ($groupMember.value -eq $false) {
        Write-Host "  Signed in user is not a member of the AKS admin group, adding now." -ForegroundColor Yellow
        az ad group member add --group $aksAADGroupName --member-id (az ad signed-in-user show --query id -o tsv)
        if (!$?) {
            Write-Host "  Something went wrong. Please check the error and try again." -ForegroundColor Red
            break   
        }
        Write-Host "  User added to Azure AD group." -ForegroundColor Green
    }
    else {
        Write-Host "  The signed in user is already a member of the Azure AD group. " -ForegroundColor Yellow
    }
}

