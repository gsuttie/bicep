function Connect-Kubernetes($aksClusterName, $resourceGroupNameAKS) {
    $maxRetries = 5
    $retryCount = 0
    do {  
        $aksloginResult = az aks get-credentials --resource-group $resourceGroupNameAKS --name $aksClusterName --overwrite 2>&1
        # $KUBECONFIG = "$env:USERPROFILE\.azure-kubelogin"

        kubelogin convert-kubeconfig -l azurecli
        if ($aksloginResult -match 'error') {
            Write-Host $aksloginResult
            exit 1
        }
        else {
            $success = $true
        }

        $retryCount ++
    }
    until ($retryCount -eq $maxRetries -or $success -eq $true)
    if ($success -eq $false) {
        Write-Host $aksloginResult
    }
    else {
        Write-Host "Connected"
    }
}