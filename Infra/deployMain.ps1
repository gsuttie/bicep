[CmdletBinding(DefaultParametersetName='None')]
param(
   [string] [Parameter(Mandatory = $true)] $subscriptionID,
   [string] [Parameter(Mandatory = $true)] $location,
   [string] [Parameter(Mandatory = $true)] $customerName,
   [validateSet("dev", "test", "prod")][string] [Parameter(Mandatory = $true)] $environmentName,
   <# Deploy switches #>
   [switch] $deploy
)

<# Deployment scripts (PowerShell) to load #>
$Path = "$PSScriptRoot\PowerShell\"
Get-ChildItem -Path $Path -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

$deploymentID = (New-Guid).Guid

<# Set Variables #>
az account set --subscription $subscriptionID --output none
if (!$?) {
    Write-Host "Something went wrong while setting the correct subscription. Please check and try again." -ForegroundColor Red
}

$updatedBy = (az account show | ConvertFrom-Json).user.name 
$location = $location.ToLower() -replace " ", ""
$customerName = $customerName.ToLower() -replace " ", ""

$locationShortCodeMap = @{
    "westeurope" = "weu";
    "northeurope" = "neu";
    "eastus" = "eus";
    "westus" = "wus";
    "uksouth" = "uks";
    "ukwest" = "ukw"
}

$locationShortCode = $locationShortCodeMap.$location

$user = az ad signed-in-user show --query id -o tsv
az role assignment create --assignee $user --scope "/" --role "Owner"

# Check we have Permissions to deploy to 
CheckPermissions

if ($deploy) {
    <# deployment timer start #>
    $starttime = [System.DateTime]::Now

    Write-Host "Running a Bicep deployment with ID: '$deploymentID' for Customer: $customerName and Environment: '$environmentName' with a 'WhatIf' check." -ForegroundColor Green
        az deployment sub create `
        --name $deploymentID `
        --location $location `
        --template-file ./main.bicep `
        --parameters updatedBy=$updatedBy customerName=$customerName environmentName=$environmentName location=$location locationShortCode=$locationShortCode subscriptionId=$subscriptionID `
        --confirm-with-what-if `
        --output none

    if (!$?) {
        Write-Host ""
        Write-Host "Bicep deployment with ID: '$deploymentID' for Customer: $customerName and Environment: '$environmentName' Failed" -ForegroundColor Red
    }
    else {
    }

    <# Deployment timer end #>
    $endtime = [System.DateTime]::Now
    $duration = $endtime -$starttime
    Write-Host ('This deployment took : {0:mm} minutes {0:ss} seconds' -f $duration) -BackgroundColor Yellow -ForegroundColor Magenta
}