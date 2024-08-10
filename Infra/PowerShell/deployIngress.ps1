function Install-Ingress ($aksClusterName, $resourceGroupNameAKS) {

  Write-Host "Checking Helm is at least version 3..." -ForegroundColor Blue
  $helmversion = helm version --short 2> $null
  if ($helmversion -like "*v3*") {
      Write-Host "  Helm version is correct." -ForegroundColor Green
      Connect-Kubernetes -resourceGroupNameAKS $resourceGroupNameAKS -aksClusterName $aksClusterName
      Write-Host "Creating ingress namespace and deploying nginx-ingress via helm..." -ForegroundColor Blue

$ingressyaml = @"
controller:
  lifecycle:
    preStop:
      exec:
        command: ["/bin/sh", "-c", "sleep 5; /usr/local/openresty/nginx/sbin/nginx -c /etc/nginx/nginx.conf -s quit; while pgrep -x nginx; do sleep 1; done"]
"@

$ingressyaml | out-File "$PSScriptRoot/../yaml/ingress-values.yaml"

      # Create a namespace for your ingress resources
      kubectl create namespace ingress-nginx

      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx *> $null
      helm repo update *> $null
      helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx `
          --namespace ingress-nginx `
          --set controller.replicaCount=2 `
          --set controller.nodeSelector."kubernetes\.io/os"=linux `
          --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux `
          --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux `
          --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz `
          --set controller.service.externalTrafficPolicy=Local `
          -f "$PSScriptRoot/../yaml/ingress-values.yaml"
      #--set-string controller.config.enable-modsecurity=true 
      # --set-string controller.config.modsecurity-snippet='SecRuleEngine On SecRequestBodyAccess On SecAuditEngine RelevantOnly SecAuditLogParts ABIJDEFHZ SecAuditLogFormat JSON SecAuditLog /dev/stdout Include /etc/nginx/owasp-modsecurity-crs/nginx-modsecurity.conf'
      if (!$?) {
          Write-Host "  nginx-ingress not deployed check log above." -ForegroundColor red
          break
      }
      Write-Host "  nginx-ingress deployed and ready for use." -ForegroundColor Green
  }
  else {
      Write-Host "Helm 3 is not installed please install. To find out how go to https://github.com/helm/helm/releases." -ForegroundColor Red
  }
}


function Install-InternalIngressFrontDoor ($subnetName, $subscriptionID, $plsName, $aksClusterName, $resourceGroupNameAKS) {

  Write-Host "Checking Helm is at least version 3..." -ForegroundColor Blue
  $helmversion = helm version --short 2> $null
  if ($helmversion -like "*v3*") {
      Write-Host "  Helm version is correct." -ForegroundColor Green
      Connect-Kubernetes -resourceGroupNameAKS $resourceGroupNameAKS -aksClusterName $aksClusterName
      Write-Host "Creating ingress namespace and deploying nginx-ingress via helm..." -ForegroundColor Blue
      #$appid = az aks show --name $kubernetesClusterName -g $resourceGroupNameAKS --query identity.principalId

$internalingressyaml = @"
controller:
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true" 
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: $subnetName
      service.beta.kubernetes.io/azure-pls-create: "true"
      service.beta.kubernetes.io/azure-pls-ip-configuration-ip-address-count: "2"
      service.beta.kubernetes.io/azure-pls-ip-configuration-subnet: $subnetName
      service.beta.kubernetes.io/azure-pls-name: "$plsName"
      service.beta.kubernetes.io/azure-pls-visibility: $subscriptionID
  lifecycle:
    preStop:
      exec:
        command: ["/bin/sh", "-c", "sleep 5; /usr/local/openresty/nginx/sbin/nginx -c /etc/nginx/nginx.conf -s quit; while pgrep -x nginx; do sleep 1; done"]
"@

$internalingressyaml | out-File "$PSScriptRoot/../yaml/$plsName-internal-ingress.yaml"

      # Create a namespace for your ingress resources
      kubectl create namespace ingress-internal

      helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx *> $null
      helm repo update *> $null
      helm upgrade --install internal-ingress ingress-nginx/ingress-nginx `
          --namespace ingress-internal `
          --set controller.replicaCount=2 `
          --set controller.nodeSelector."kubernetes\.io/os"=linux `
          --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux `
          --set controller.extraArgs.default-ssl-certificate=ingress-internal/ingress-tls `
          --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux `
          --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz `
          --set controller.service.externalTrafficPolicy=Local `
          -f "$PSScriptRoot/../yaml/$plsName-internal-ingress.yaml"
      #--set-string controller.config.enable-modsecurity=true 
      # --set-string controller.config.modsecurity-snippet='SecRuleEngine On SecRequestBodyAccess On SecAuditEngine RelevantOnly SecAuditLogParts ABIJDEFHZ SecAuditLogFormat JSON SecAuditLog /dev/stdout Include /etc/nginx/owasp-modsecurity-crs/nginx-modsecurity.conf'
      #$helmcheck = helm status nginx-ingress --namespace nginx-ingress
      #if ($helmcheck -notcontains "STATUS: deployed") {


      #kubectl delete -A ValidatingWebhookConfiguration internal-ingress-ingress-nginx-admission
      if (!$?) {
          Write-Host "  nginx-ingress not deployed check log above." -ForegroundColor red
          break
      }
      Write-Host "  nginx-ingress deployed and ready for use." -ForegroundColor Green
  }
  else {
      Write-Host "Helm 3 is not installed please install. To find out how go to https://github.com/helm/helm/releases." -ForegroundColor Red
  }
}

function installInternalIngressCSI ($subnetName, $subscriptionID, $environmentName, $unit, $kubernetesClusterName, $resourceGroupNameAKS, $locationShortCode, $keyvaultName) {
    $MIClientId = az identity show --name id-aks-$environmentName-$unit-$locationShortCode-kubelet --resource-group $resourceGroupNameAKS --query clientId --output tsv

    Write-Host "Setting Get permission for VMSS Managed Identity to $keyvaultName Key Vault..." -ForegroundColor Blue
    az keyvault set-policy --subscription $subscriptionID --name $keyvaultName --secret-permissions get --spn $MIClientId --output none
    az keyvault set-policy --subscription $subscriptionID --name $keyvaultName --key-permissions get --spn $MIClientId --output none
    az keyvault set-policy --subscription $subscriptionID --name $keyvaultName --certificate-permissions get --spn $MIClientId --output none
    Write-Host "  Access set." -ForegroundColor Green

    Write-Host "Obtaining tenant ID..."

    $tenantid = az account show --query tenantId --output tsv

    # Dev vs. Prod Logic for Secret Provider Class and Health Probe (Ingress Check)
    if ($unit -eq "dev") {
      $healthProbeHostname = "ingress.rand.io"
      $healthProbeCertName = "wildcard-rand-io"
    }
    if ($unit -eq "prod") {
      $healthProbeHostname = "ingress.rand.networks"
      $healthProbeCertName = "wildcard-rand-networks"
    }

    $internalingressyaml = @"
controller:
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true" 
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: $subnetName
      service.beta.kubernetes.io/azure-pls-create: "true"
      service.beta.kubernetes.io/azure-pls-ip-configuration-ip-address-count: "2"
      service.beta.kubernetes.io/azure-pls-ip-configuration-subnet: $subnetName
      service.beta.kubernetes.io/azure-pls-name: "pls-aks-$environmentName-$unit"
      service.beta.kubernetes.io/azure-pls-visibility: $subscriptionID   
  extraVolumes:
      - name: secrets-store-inline
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "azure-tls"
  extraVolumeMounts:
      - name: secrets-store-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true   
"@

$internalingressyaml | out-File "$PSScriptRoot\..\yaml\$environmentName-$unit-$locationShortCode-internal-ingress.yaml"

$SecretProviderClass = @"
# This is SecretProviderClass example using service-principal for authentication with Key Vault
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-tls
  namespace: ingress-internal
spec:
  provider: azure
  secretObjects:                                # secretObjects defines the desired state of synced K8s secret objects
  - secretName: $healthProbeCertName
    type: kubernetes.io/tls
    data: 
    - objectName: $healthProbeCertName
      key: tls.key
    - objectName: $healthProbeCertName
      key: tls.crt
  parameters:
    usePodIdentity: "false"         # [OPTIONAL] if not provided, will default to "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "$MIClientId"
    keyvaultName: "$keyvaultName"          # the name of the KeyVault
    cloudName: ""          # [OPTIONAL for Azure] if not provided, azure environment will default to AzurePublicCloud 
    objects:  |
      array:
        - |
          objectName: $healthProbeCertName
          objectType: secret        # object types: secret, key or cert
          objectVersion: ""         # [OPTIONAL] object versions, default to latest if empty
    resourceGroup: "$resourceGroupNameKV"     # [REQUIRED] the resource group name of the key vault
    subscriptionId: "$subscriptionid"          # [REQUIRED] the subscription ID of the key vault
    tenantId: "$tenantid"
"@
    
    $SecretProviderClass | out-File "$PSScriptRoot\..\yaml\SecretProviderClass.yaml"
    
    Write-Host "Applying Secret Provider Class to AKS cluster..." -ForegroundColor Blue
    kubectl apply -f "$PSScriptRoot\..\yaml\SecretProviderClass.yaml" > $null 
    Write-Host "  Secret Provider Class applied to AKS cluster..." -ForegroundColor Green
        
    Write-Host "Checking Helm is at least version 3..." -ForegroundColor Blue
    $helmversion = helm version --short 2> $null
    if ($helmversion -like "*v3*") {
        Write-Host "  Helm version is correct." -ForegroundColor Green
        Connect-Kubernetes -resourceGroupNameAKS $resourceGroupNameAKS -kubernetesClusterName $kubernetesClusterName
        Write-Host "Creating ingress-internal namespace and deploying nginx-ingress via helm..." -ForegroundColor Blue
        #$appid = az aks show --name $kubernetesClusterName -g $resourceGroupNameAKS --query identity.principalId

        # Create a namespace for your ingress resources
        kubectl create namespace ingress-internal

        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx *> $null
        helm repo update *> $null
        helm upgrade --install internal-ingress ingress-nginx/ingress-nginx `
            --namespace ingress-internal `
            --set controller.replicaCount=2 `
            --set controller.nodeSelector."kubernetes\.io/os"=linux `
            --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux `
            --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux `
            --set controller.admissionWebhooks.enabled=false `
            --set controller.service.externalTrafficPolicy=Local `
            -f "$PSScriptRoot\..\yaml\$environmentName-$unit-$locationShortCode-internal-ingress.yaml"
        #--set-string controller.config.enable-modsecurity=true --set-string controller.config.modsecurity-snippet='SecRuleEngine On SecRequestBodyAccess On SecAuditEngine RelevantOnly SecAuditLogParts ABIJDEFHZ SecAuditLogFormat JSON SecAuditLog /dev/stdout Include /etc/nginx/owasp-modsecurity-crs/nginx-modsecurity.conf'
        #$helmcheck = helm status nginx-ingress --namespace nginx-ingress
        #if ($helmcheck -notcontains "STATUS: deployed") {


        # Start-Sleep -Seconds 60

        #kubectl delete -A ValidatingWebhookConfiguration internal-ingress-ingress-nginx-admission
        if (!$?) {
            Write-Host "  nginx-ingress not deployed check log above." -ForegroundColor red
            break
        }
        Write-Host "  nginx-ingress deployed and ready for use." -ForegroundColor Green
    }
    else {
        Write-Host "Helm 3 is not installed please install. To find out how go to https://github.com/helm/helm/releases." -ForegroundColor Red
    }


$ingressCheck = @"
kind: Deployment
apiVersion: apps/v1
metadata:
  name: ingress-check
  namespace: ingress-internal
  labels:
    app: ingress-check
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ingress-check
  template:
    metadata:
      labels:
        app: ingress-check
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
              protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  name: ingress-check
  namespace: ingress-internal
  labels:
    app: ingress-check
spec:
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  selector:
    app: ingress-check
  type: ClusterIP
---
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: ingress-check
  namespace: ingress-internal
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
spec:
  ingressClassName: internal-ingress
  tls:
    - hosts:
        - $healthProbeHostname
      secretName: $healthProbeCertName
  rules:
    - host: $healthProbeHostname
      http:
        paths:
          - pathType: ImplementationSpecific
            backend:
              service:
                name: ingress-check
                port:
                  number: 80
"@

        $ingressCheck | out-File "$PSScriptRoot\..\yaml\ingresscheck.yaml"
        Write-Host "Applying Ingress Check to AKS cluster..." -ForegroundColor Blue
        kubectl apply -f "$PSScriptRoot\..\yaml\ingresscheck.yaml" > $null 
        Write-Host "  Ingress Check applied to AKS cluster..." -ForegroundColor Green

}