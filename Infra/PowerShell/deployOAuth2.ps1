function Install-OAuth2 ($aksClusterName, $resourceGroupNameAKS, $WebRedirectHostname, $appName) {
    
    Write-Host "Creating App Registration to be used with Web App Azure AD Authentication." -ForegroundColor Yellow

    $cookieToken = (-join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 32 |%{[char]$_}))
    $WebRedirectHostname

    az ad app create `
    --display-name "$aksClusterName-$appName-oauth2" `
    --web-redirect-uris "https://$WebRedirectHostname/oauth2/callback" `
    --sign-in-audience AzureADMyOrg `
    --output None

    $appID = az ad app list --display-name "$aksClusterName-$appName-oauth2" --query [].appId --output tsv
    $appSecret = az ad app credential reset --id $appID --display-name "$aksClusterName-$appName-oauth2" --query password --output tsv
    $tenantid = az account show --subscription $subscriptionID --query tenantId --output tsv

    Connect-Kubernetes -resourceGroupNameAKS $resourceGroupNameAKS -aksClusterName $aksClusterName

    # Create a namespace for your oauth2 resources
    kubectl create namespace $appName-oauth2-proxy

    # create secret needed for oauth2-proxy
    kubectl create secret generic $appName-oauth2-proxy-creds `
    --namespace oauth2-proxy `
    --from-literal=cookie-secret=$cookieToken `
    --from-literal=client-id=$appID `
    --from-literal=client-secret=$appSecret `
      
    $appSecret = ""
    $cookieToken = ""

    if (!$?) {
        Write-Host "  Something went wrong. Please check the error and try again." -ForegroundColor Red
        break   
    }
    else {
        Write-Host "  App Registration created." -ForegroundColor Green
    }

    Write-Host "Checking Helm is at least version 3..." -ForegroundColor Blue
    $helmversion = helm version --short 2> $null
    if ($helmversion -like "*v3*") {
        Write-Host "  Helm version is correct." -ForegroundColor Green
        Write-Host "Creating oAuth2 namespace and deploying oauth2-proxy via helm..." -ForegroundColor Blue


$oauth2yaml = @"
config:
  existingSecret: $appName-oauth2-proxy-creds

extraArgs:
  provider: azure
  azure-tenant: $tenantid
  email-domain: "*"
  oidc-issuer-url: https://login.microsoftonline.com/$tenantid/v2.0

ingress:
  enabled: true
  path: /oauth2
  pathType: Prefix
"@

$oauth2yaml | out-File "$PSScriptRoot/../yaml/$appName-oauth2-values.yaml"

      helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests *> $null
      helm repo update *> $null
      helm upgrade --install oauth2-proxy oauth2-proxy/oauth2-proxy `
          --namespace $appName-oauth2-proxy `
          -f "$PSScriptRoot/../yaml/oauth2-values.yaml"
      
      if (!$?) {
          Write-Host "  oAuth2 not deployed check log above." -ForegroundColor red
          break
      }
      Write-Host "  oAuth2 deployed and ready for use." -ForegroundColor Green
  }
  else {
      Write-Host "Helm 3 is not installed please install. To find out how go to https://github.com/helm/helm/releases." -ForegroundColor Red
  }
}