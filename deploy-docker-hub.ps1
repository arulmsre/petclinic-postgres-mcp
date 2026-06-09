# PetClinic Deployment Script (Docker Hub + AKS + Azure Postgres)

param(
    [string]$ResourceGroupName = "petclinic-rg",
    [string]$Location = "eastus2",
    [string]$AksName = "petclinic-aks",

    # Docker Hub
    [string]$DockerHubUser = "arul1985",

    # PostgreSQL
    [string]$PostgresServerName = "petclinic-postgres-db",
    [string]$PostgresAdminUser = "petclinicadmin",
    [string]$PostgresAdminPassword = "P@ssw0rd123!",
    [string]$PostgresDatabase = "petclinic",

    # AKS
    [int]$AksNodeCount = 2,
    [string]$AksNodeSize = "Standard_DC2s_v3",

    # Flags
    [switch]$SkipLogin,
    [switch]$SkipResourceCreation,
    [switch]$SkipBuild,
    [switch]$SkipDeploy,
    [switch]$SkipPortForward
)

function Write-Step { param($m) ; Write-Host "`n==== $m ====`n" -ForegroundColor Cyan }
function Write-Info { param($m) ; Write-Host "[INFO] $m" -ForegroundColor Yellow }
function Write-OK   { param($m) ; Write-Host "[OK]   $m" -ForegroundColor Green }
function Write-Err  { param($m) ; Write-Host "[ERR]  $m" -ForegroundColor Red }

$ErrorActionPreference = "Stop"

try {
    # -----------------------------
    # PREREQUISITES
    # -----------------------------
    Write-Step "Checking Prerequisites"

    Write-Info "Checking Azure CLI..."
    az version 2>$null | Out-Null
    Write-OK "Azure CLI is installed"

    Write-Info "Checking kubectl..."
    kubectl version --client 2>$null | Out-Null
    Write-OK "kubectl is installed"

    if (-not $SkipBuild) {
        Write-Info "Checking Maven wrapper or Maven..."
        $mvnwPath = Join-Path $PSScriptRoot "mvnw.cmd"
        if (Test-Path $mvnwPath) {
            Write-OK "Found mvnw.cmd"
            $script:MavenCommand = $mvnwPath
        } else {
            mvn --version 2>$null | Out-Null
            Write-OK "Maven is installed"
            $script:MavenCommand = "mvn"
        }

        Write-Info "Checking Docker..."
        docker --version 2>$null | Out-Null
        Write-OK "Docker is installed"
    }

    # -----------------------------
    # STEP 1 — Azure Login
    # -----------------------------
    if (-not $SkipLogin) {
        Write-Step "STEP 1: Azure Login"

        $acct = az account show 2>$null | ConvertFrom-Json
        if ($acct) {
            Write-OK "Already logged in as $($acct.user.name)"
        } else {
            Write-Info "Logging into Azure..."
            az login | Out-Null
            Write-OK "Login successful"
        }
    } else {
        Write-Info "Skipping Azure login"
    }

    # -----------------------------
    # STEP 2 — Resource Group
    # -----------------------------
    if (-not $SkipResourceCreation) {
        Write-Step "STEP 2: Resource Group"

        $rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
        if ($rgExists) {
            Write-Info "Resource group '$ResourceGroupName' already exists"
        } else {
            Write-Info "Creating resource group..."
            az group create --name $ResourceGroupName --location $Location | Out-Null
            Write-OK "Resource group created"
        }

        Write-Info "Ensuring required providers are registered..."
        $providers = @(
            "Microsoft.ContainerService",
            "Microsoft.DBforPostgreSQL",
            "Microsoft.Insights",
            "Microsoft.OperationalInsights"
        )
        foreach ($p in $providers) {
            $state = az provider show --namespace $p --query "registrationState" -o tsv 2>$null
            if ($state -ne "Registered") {
                Write-Info "Registering provider $p..."
                az provider register --namespace $p --wait | Out-Null
            } else {
                Write-Info "$p already registered"
            }
        }
        Write-OK "Providers ready"
    } else {
        Write-Info "Skipping resource group creation"
    }

    # -----------------------------
    # STEP 3 — Skipping ACR
    # -----------------------------
    Write-Step "STEP 3: Skipping ACR (Using Docker Hub)"

    # -----------------------------
    # STEP 4 — AKS Cluster
    # -----------------------------
    if (-not $SkipResourceCreation) {
        Write-Step "STEP 4: AKS Cluster"

        Write-Info "Checking if AKS cluster exists..."
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $aksCheck = az aks show --name $AksName --resource-group $ResourceGroupName 2>$null
        $aksExists = $?
        $ErrorActionPreference = $prev

        if ($aksExists) {
            Write-Info "AKS cluster '$AksName' already exists"
        } else {
            Write-Info "Creating AKS cluster '$AksName'..."
            az aks create `
                --resource-group $ResourceGroupName `
                --name $AksName `
                --node-count $AksNodeCount `
                --node-vm-size $AksNodeSize `
                --enable-addons monitoring `
                --generate-ssh-keys | Out-Null
            Write-OK "AKS cluster created"
        }

        Write-Info "Getting AKS credentials..."
        az aks get-credentials --resource-group $ResourceGroupName --name $AksName --overwrite-existing | Out-Null
        Write-OK "AKS credentials configured"

        Write-Info "Verifying AKS connection..."
        kubectl get nodes
        Write-OK "Connected to AKS"
    } else {
        Write-Info "Skipping AKS creation"
    }

    # -----------------------------
    # STEP 5 — PostgreSQL Flexible Server
    # -----------------------------
    if (-not $SkipResourceCreation) {
        Write-Step "STEP 5: PostgreSQL Flexible Server"

        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $pgCheck = az postgres flexible-server show `
            --name $PostgresServerName `
            --resource-group $ResourceGroupName 2>$null
        $pgExists = $?
        $ErrorActionPreference = $prev

        if ($pgExists) {
            Write-Info "PostgreSQL server '$PostgresServerName' already exists"
        } else {
            Write-Info "Creating PostgreSQL server '$PostgresServerName'..."
            az postgres flexible-server create `
                --resource-group $ResourceGroupName `
                --name $PostgresServerName `
                --location $Location `
                --admin-user $PostgresAdminUser `
                --admin-password $PostgresAdminPassword `
                --sku-name Standard_B1ms `
                --tier Burstable `
                --storage-size 32 `
                --version 15 `
                --public-access 0.0.0.0-255.255.255.255 | Out-Null
            Write-OK "PostgreSQL server created"
        }

        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $pgDbCheck = az postgres flexible-server db show `
            --resource-group $ResourceGroupName `
            --server-name $PostgresServerName `
            --database-name $PostgresDatabase 2>$null
        $pgDbExists = $?
        $ErrorActionPreference = $prev

        if ($pgDbExists) {
            Write-Info "Database '$PostgresDatabase' already exists"
        } else {
            Write-Info "Creating database '$PostgresDatabase'..."
            az postgres flexible-server db create `
                --resource-group $ResourceGroupName `
                --server-name $PostgresServerName `
                --database-name $PostgresDatabase | Out-Null
            Write-OK "Database created"
        }

        $pgHost = az postgres flexible-server show `
            --name $PostgresServerName `
            --resource-group $ResourceGroupName `
            --query "fullyQualifiedDomainName" -o tsv

        $pgConnectionString = "jdbc:postgresql://$pgHost:5432/$PostgresDatabase?user=$PostgresAdminUser&password=$PostgresAdminPassword"
        Write-Info "PostgreSQL Host: $pgHost"
        Write-Info "JDBC Connection String (for reference): $pgConnectionString"
    } else {
        Write-Info "Skipping PostgreSQL creation"
    }

    # -----------------------------
    # STEP 6 — Build + Push to Docker Hub
    # -----------------------------
    if (-not $SkipBuild) {
        Write-Step "STEP 6: Build + Push Docker Images to Docker Hub"

        Write-Info "Logging into Docker Hub..."
        docker login

        Write-Info "Building PetClinic microservices with Maven..."
        & $script:MavenCommand clean install -DskipTests
        if ($LASTEXITCODE -ne 0) {
            throw "Maven build failed"
        }
        Write-OK "Maven build completed"

        $services = @(
            "spring-petclinic-config-server",
            "spring-petclinic-discovery-server",
            "spring-petclinic-api-gateway",
            "spring-petclinic-customers-service",
            "spring-petclinic-vets-service",
            "spring-petclinic-visits-service",
            "spring-petclinic-admin-server"
        )

        foreach ($svc in $services) {
            Write-Info "Building image for $svc..."
            docker build -t "$DockerHubUser/$svc:latest" -f ".\$svc\Dockerfile" ".\$svc"
            docker push "$DockerHubUser/$svc:latest"
            Write-OK "$svc pushed to Docker Hub"
        }

        Write-Info "Building MCP images..."
        docker build -t "$DockerHubUser/prometheus-mcp-http:latest" -f Dockerfile.prometheus-http .
        docker push "$DockerHubUser/prometheus-mcp-http:latest"
        Write-OK "Prometheus MCP pushed"

        docker build -t "$DockerHubUser/grafana-mcp-http:latest" -f Dockerfile.grafana-http .
        docker push "$DockerHubUser/grafana-mcp-http:latest"
        Write-OK "Grafana MCP pushed"

        docker build -t "$DockerHubUser/postgres-mcp-http:latest" -f Dockerfile.postgres-http .
        docker push "$DockerHubUser/postgres-mcp-http:latest"
        Write-OK "Postgres MCP pushed"

        Write-OK "All images built and pushed to Docker Hub"
    } else {
        Write-Info "Skipping Docker build/push"
    }

    # -----------------------------
    # STEP 7 — Deploy PetClinic
    # -----------------------------
    if (-not $SkipDeploy) {
        Write-Step "STEP 7: Deploy PetClinic with Observability"

        Write-Info "Applying PetClinic + monitoring manifests..."
        kubectl apply -f k8s/petclinic-with-monitoring-0127.yaml
        Write-OK "PetClinic manifests applied"

        Write-Info "Waiting for core services to become ready..."
        Start-Sleep -Seconds 30

        kubectl wait --for=condition=ready pod -l app=config-server -n petclinic --timeout=300s 2>$null
        kubectl wait --for=condition=ready pod -l app=discovery-server -n petclinic --timeout=300s 2>$null
        kubectl wait --for=condition=ready pod -l app=api-gateway -n petclinic --timeout=300s 2>$null

        Write-OK "Core PetClinic services are ready"
        Write-Info "Current pods:"
        kubectl get pods -n petclinic
    } else {
        Write-Info "Skipping PetClinic deployment"
    }

    # -----------------------------
    # STEP 8 — Deploy MCP Servers
    # -----------------------------
    if (-not $SkipDeploy) {
        Write-Step "STEP 8: Deploy MCP Servers"

        Write-Info "Applying MCP server manifests..."
    #   kubectl apply -f k8s/mcp-servers.yaml
        Write-OK "MCP manifests applied"

        Write-Info "Waiting for MCP pods..."
        Start-Sleep -Seconds 20

        kubectl wait --for=condition=ready pod -l app=prometheus-mcp -n petclinic --timeout=120s 2>$null
        kubectl wait --for=condition=ready pod -l app=grafana-mcp -n petclinic --timeout=120s 2>$null
        kubectl wait --for=condition=ready pod -l app=postgres-mcp -n petclinic --timeout=120s 2>$null

        Write-OK "MCP servers are ready"
    } else {
        Write-Info "Skipping MCP deployment"
    }

    # -----------------------------
    # STEP 9 — Service Endpoints
    # -----------------------------
    Write-Step "STEP 9: Retrieving Service Endpoints"

    Write-Info "Waiting for LoadBalancer IPs (60s)..."
    Start-Sleep -Seconds 60

    $apiGatewayIP = kubectl get svc api-gateway -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    $grafanaIP    = kubectl get svc grafana -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null

    Write-Info "API Gateway IP: $apiGatewayIP"
    Write-Info "Grafana IP:     $grafanaIP"

    # -----------------------------
    # STEP 10 — Port Forward MCP
    # -----------------------------
    if (-not $SkipPortForward) {
        Write-Step "STEP 10: Port-Forward MCP Servers"

        Start-Process powershell -ArgumentList "-NoExit","-Command","Write-Host 'Prometheus MCP (8090→80)'; kubectl port-forward -n petclinic svc/prometheus-mcp-service 8090:80"
        Start-Process powershell -ArgumentList "-NoExit","-Command","Write-Host 'Grafana MCP (8091→80)'; kubectl port-forward -n petclinic svc/grafana-mcp-service 8091:80"
        Start-Process powershell -ArgumentList "-NoExit","-Command","Write-Host 'Postgres MCP (8092→80)'; kubectl port-forward -n petclinic svc/postgres-mcp-service 8092:80"

        Write-OK "Port-forwards started in separate windows"
    } else {
        Write-Info "Skipping port-forward setup"
    }

    Write-Step "DEPLOYMENT COMPLETE"

} catch {
    Write-Err "Deployment failed: $($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}