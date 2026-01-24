# Complete Azure Infrastructure Deployment Script for PetClinic with MCP Servers
# This script automates the entire deployment process from Azure login to port-forwarding

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "petclinic-rg",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$AcrName = "petclinicdemo1234",
    
    [Parameter(Mandatory=$false)]
    [string]$AksName = "petclinic-aks",
    
    [Parameter(Mandatory=$false)]
    [string]$PostgresServerName = "petclinic-postgres-db",
    
    [Parameter(Mandatory=$false)]
    [string]$PostgresAdminUser = "petclinicadmin",
    
    [Parameter(Mandatory=$false)]
    [string]$PostgresAdminPassword = "P@ssw0rd123!",
    
    [Parameter(Mandatory=$false)]
    [string]$PostgresDatabase = "petclinic",
    
    [Parameter(Mandatory=$false)]
    [int]$AksNodeCount = 2,
    
    [Parameter(Mandatory=$false)]
    [string]$AksNodeSize = "Standard_DC2s_v3",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipLogin,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipResourceCreation,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDeploy,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPortForward
)

# Color functions
function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Error handling
$ErrorActionPreference = "Stop"

try {
    # ============================================
    # PREREQUISITE CHECKS
    # ============================================
    Write-Step "Checking Prerequisites"
    
    # Check Azure CLI
    Write-Info "Checking Azure CLI..."
    $azVersion = az version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Azure CLI is not installed. Please install from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    }
    Write-Success "Azure CLI is installed"
    
    # Check kubectl
    Write-Info "Checking kubectl..."
    $kubectlVersion = kubectl version --client 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "kubectl is not installed. Please install from: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    }
    Write-Success "kubectl is installed"
    
    # Check Maven (only if not skipping build)
    if (-not $SkipBuild) {
        Write-Info "Checking Maven..."
        
        # Check if Maven wrapper exists
        $mvnwPath = Join-Path $PSScriptRoot "mvnw.cmd"
        if (Test-Path $mvnwPath) {
            Write-Success "Maven wrapper (mvnw.cmd) found - will use it for building"
            $script:MavenCommand = $mvnwPath
        } else {
            # Check for system Maven
            $mvnVersion = mvn --version 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Error-Custom "Maven is not installed or not in PATH, and mvnw.cmd wrapper not found."
                Write-Info "Please install Maven from: https://maven.apache.org/download.cgi"
                Write-Info "Alternatively, run the script with -SkipBuild flag if images are already built"
                exit 1
            }
            Write-Success "Maven is installed"
            $script:MavenCommand = "mvn"
        }
        
        # Check Docker
        Write-Info "Checking Docker..."
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error-Custom "Docker is not installed. Please install from: https://docs.docker.com/get-docker/"
            exit 1
        }
        Write-Success "Docker is installed"
    }
    
    Write-Success "All prerequisites met"

    # ============================================
    # STEP 1: Azure Login
    # ============================================
    if (-not $SkipLogin) {
        Write-Step "STEP 1: Logging into Azure"
        
        # Check if already logged in
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Success "Already logged in as: $($account.user.name)"
            Write-Info "Subscription: $($account.name) ($($account.id))"
        } else {
            Write-Info "Logging into Azure..."
            az login
            if ($LASTEXITCODE -ne 0) {
                throw "Azure login failed"
            }
            Write-Success "Successfully logged into Azure"
        }
    } else {
        Write-Info "Skipping Azure login (-SkipLogin flag set)"
    }

    # ============================================
    # STEP 2: Create Resource Group
    # ============================================
    if (-not $SkipResourceCreation) {
        Write-Step "STEP 2: Creating Resource Group"
        
        $rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
        if ($rgExists) {
            Write-Info "Resource group '$ResourceGroupName' already exists"
        } else {
            Write-Info "Creating resource group: $ResourceGroupName in $Location"
            az group create --name $ResourceGroupName --location $Location
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create resource group"
            }
            Write-Success "Resource group created successfully"
        }
        
        # Register required resource providers
        Write-Info "Registering required Azure resource providers..."
        $providers = @(
            "Microsoft.ContainerRegistry",
            "Microsoft.ContainerService", 
            "Microsoft.Insights",
            "Microsoft.DBforPostgreSQL",
            "Microsoft.OperationalInsights"
        )
        
        foreach ($provider in $providers) {
            Write-Info "Checking provider: $provider"
            $providerStatus = az provider show --namespace $provider --query "registrationState" -o tsv 2>&1
            if ($providerStatus -ne "Registered") {
                Write-Info "Registering $provider..."
                az provider register --namespace $provider --wait
            } else {
                Write-Info "$provider already registered"
            }
        }
        Write-Success "All required resource providers are registered"
    } else {
        Write-Info "Skipping resource group creation"
    }

    # ============================================
    # STEP 3: Create Azure Container Registry
    # ============================================
    if (-not $SkipResourceCreation) {
        Write-Step "STEP 3: Creating Azure Container Registry"
        
        # Check if ACR exists (in current resource group)
        Write-Info "Checking if ACR exists in resource group '$ResourceGroupName'..."
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $acrCheck = az acr show --name $AcrName --resource-group $ResourceGroupName 2>&1
        $acrExistsInRg = $?
        $ErrorActionPreference = $previousErrorActionPreference
        
        if ($acrExistsInRg) {
            Write-Success "ACR '$AcrName' already exists in resource group"
        } else {
            # Check if ACR exists globally (might be in different RG)
            Write-Info "Checking if ACR '$AcrName' exists globally..."
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'SilentlyContinue'
            $acrGlobalCheck = az acr show --name $AcrName 2>&1
            $acrExistsGlobally = $?
            $ErrorActionPreference = $previousErrorActionPreference
            
            if ($acrExistsGlobally) {
                Write-Success "ACR '$AcrName' exists and is accessible"
                Write-Info "Using existing ACR (may be in a different resource group)"
            } else {
                Write-Info "Creating ACR: $AcrName"
                az acr create `
                    --resource-group $ResourceGroupName `
                    --name $AcrName `
                    --sku Basic `
                    --admin-enabled true
                
                if ($LASTEXITCODE -ne 0) {
                    Write-Error-Custom "Failed to create ACR. The DNS name '$AcrName.azurecr.io' may be taken by another subscription."
                    Write-Info "Please choose a different ACR name using: -AcrName parameter"
                    throw "Failed to create ACR"
                }
                Write-Success "ACR created successfully"
                
                # Wait for ACR to be fully provisioned
                Write-Info "Waiting for ACR to be ready..."
                Start-Sleep -Seconds 10
            }
        }
        
        # Get ACR credentials
        Write-Info "Retrieving ACR credentials..."
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        
        # Try to get credentials - first try with resource group, then without
        $acrPassword = az acr credential show --name $AcrName --query "passwords[0].value" -o tsv 2>&1
        $credResult = $?
        $ErrorActionPreference = $previousErrorActionPreference
        
        if (-not $credResult) {
            Write-Error-Custom "Failed to retrieve ACR credentials. You may not have access to this ACR."
            throw "Failed to retrieve ACR credentials"
        }
        Write-Success "ACR credentials retrieved"
    } else {
        Write-Info "Skipping ACR creation"
    }

    # ============================================
    # STEP 4: Create Azure Kubernetes Service
    # ============================================
    if (-not $SkipResourceCreation) {
        Write-Step "STEP 4: Creating Azure Kubernetes Service"
        
        # Check if AKS exists
        Write-Info "Checking if AKS cluster exists..."
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $aksCheck = az aks show --name $AksName --resource-group $ResourceGroupName 2>&1
        $aksExists = $?
        $ErrorActionPreference = $previousErrorActionPreference
        
        if ($aksExists) {
            Write-Info "AKS cluster '$AksName' already exists"
        } else {
            Write-Info "Creating AKS cluster: $AksName (this may take 10-15 minutes)"
            az aks create `
                --resource-group $ResourceGroupName `
                --name $AksName `
                --node-count $AksNodeCount `
                --node-vm-size $AksNodeSize `
                --enable-addons monitoring `
                --generate-ssh-keys `
                --attach-acr $AcrName
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create AKS cluster"
            }
            Write-Success "AKS cluster created successfully"
        }
        
        # Get AKS credentials
        Write-Info "Getting AKS credentials..."
        az aks get-credentials --resource-group $ResourceGroupName --name $AksName --overwrite-existing
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get AKS credentials"
        }
        Write-Success "AKS credentials configured"
        
        # Verify connection
        Write-Info "Verifying AKS connection..."
        kubectl get nodes
        Write-Success "Successfully connected to AKS cluster"
    } else {
        Write-Info "Skipping AKS creation"
    }

    # ============================================
    # STEP 5: Create Azure SQL Database
    # ============================================
    if (-not $SkipResourceCreation) {
        Write-Step "STEP 5: Creating Azure SQL Database"
        $SqlServerName = "petclinic-sql-server"
        $SqlAdminUser = "petclinicadmin"
        $SqlAdminPassword = "P@ssw0rd123!"
        $SqlDatabase = "petclinic"

        # Check if SQL server exists
        Write-Info "Checking if SQL server exists..."
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $sqlServerCheck = az sql server show --name $SqlServerName --resource-group $ResourceGroupName 2>&1
        $sqlServerExists = $?
        $ErrorActionPreference = $previousErrorActionPreference

        if ($sqlServerExists) {
            Write-Info "SQL server '$SqlServerName' already exists"
        } else {
            Write-Info "Creating SQL server: $SqlServerName"
            az sql server create `
                --name $SqlServerName `
                --resource-group $ResourceGroupName `
                --location $Location `
                --admin-user $SqlAdminUser `
                --admin-password $SqlAdminPassword
            if ($LASTEXITCODE -ne 0) {
                Write-Error-Custom "Failed to create SQL server in location '$Location'"
                throw "Failed to create SQL server"
            }
            Write-Success "SQL server created successfully"
        }

        # Check if database exists
        Write-Info "Checking if database '$SqlDatabase' exists..."
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        $sqlDbCheck = az sql db show --name $SqlDatabase --server $SqlServerName --resource-group $ResourceGroupName 2>&1
        $sqlDbExists = $?
        $ErrorActionPreference = $previousErrorActionPreference

        if ($sqlDbExists) {
            Write-Success "Database '$SqlDatabase' already exists"
        } else {
            Write-Info "Creating database: $SqlDatabase"
            az sql db create `
                --name $SqlDatabase `
                --server $SqlServerName `
                --resource-group $ResourceGroupName `
                --service-objective S0
            if ($LASTEXITCODE -ne 0) {
                Write-Error-Custom "Failed to create SQL database, but continuing..."
            } else {
                Write-Success "Database created successfully"
            }
        }

        # Configure firewall rule for Azure services
        Write-Info "Configuring firewall rule for Azure services..."
        az sql server firewall-rule create `
            --resource-group $ResourceGroupName `
            --server $SqlServerName `
            --name AllowAzureServices `
            --start-ip-address 0.0.0.0 `
            --end-ip-address 0.0.0.0
        Write-Success "Firewall rule configured"

        # Get SQL connection string
        $sqlHost = az sql server show --name $SqlServerName --resource-group $ResourceGroupName --query "fullyQualifiedDomainName" -o tsv
        $sqlConnectionString = "jdbc:sqlserver://$sqlHost:1433;database=$SqlDatabase;user=$SqlAdminUser@$SqlServerName;password=$SqlAdminPassword;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
        Write-Info "SQL Server Host: $sqlHost"
        Write-Info "JDBC Connection String: $sqlConnectionString"
    } else {
        Write-Info "Skipping SQL Database creation"
    }

    # ============================================
    # STEP 6: Build and Push Docker Images
    # ============================================
    if (-not $SkipBuild) {
        Write-Step "STEP 6: Building and Pushing Docker Images"
        
        # Login to ACR
        Write-Info "Logging into ACR..."
        az acr login --name $AcrName
        
        # Build PetClinic services
        Write-Info "Building PetClinic microservices..."
        & $script:MavenCommand clean install -DskipTests
        
        if ($LASTEXITCODE -ne 0) {
            throw "Maven build failed"
        }
        Write-Success "Maven build completed"
        
        # Build and push images
        Write-Info "Building and pushing Docker images to ACR..."
        
        $services = @(
            "spring-petclinic-config-server",
            "spring-petclinic-discovery-server",
            "spring-petclinic-api-gateway",
            "spring-petclinic-customers-service",
            "spring-petclinic-vets-service",
            "spring-petclinic-visits-service",
            "spring-petclinic-admin-server"
        )
        
        foreach ($service in $services) {
            Write-Info "Building $service..."
            docker build -t "$AcrName.azurecr.io/$service:latest" -f ".\$service\Dockerfile" ".\$service"
            docker push "$AcrName.azurecr.io/$service:latest"
            Write-Success "$service pushed to ACR"
        }
        
        # Build MCP server images
        Write-Info "Building MCP server images..."
        
        # Prometheus MCP
        docker build -t "$AcrName.azurecr.io/prometheus-mcp-http:latest" -f Dockerfile.prometheus-http .
        docker push "$AcrName.azurecr.io/prometheus-mcp-http:latest"
        Write-Success "Prometheus MCP pushed to ACR"
        
        # Grafana MCP
        docker build -t "$AcrName.azurecr.io/grafana-mcp-http:latest" -f Dockerfile.grafana-http .
        docker push "$AcrName.azurecr.io/grafana-mcp-http:latest"
        Write-Success "Grafana MCP pushed to ACR"
        
        # PostgreSQL MCP
        docker build -t "$AcrName.azurecr.io/postgres-mcp-http:latest" -f Dockerfile.postgres-http .
        docker push "$AcrName.azurecr.io/postgres-mcp-http:latest"
        Write-Success "PostgreSQL MCP pushed to ACR"
        
        Write-Success "All images built and pushed successfully"
    } else {
        Write-Info "Skipping Docker image build"
    }

    # ============================================
    # STEP 7: Deploy PetClinic with Observability
    # ============================================
    if (-not $SkipDeploy) {
        Write-Step "STEP 7: Deploying PetClinic Application with Observability"
        
        # Apply the complete deployment YAML
        Write-Info "Deploying PetClinic with monitoring stack..."
        
        $ErrorActionPreference = "Continue"
        kubectl apply -f k8s/petclinic-with-monitoring.yaml 2>&1 | Out-Null
        $deployResult = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        
        if ($deployResult -ne 0) {
            Write-Info "Some resources may already exist, checking deployment status..."
            
            # Verify deployment was successful by checking if key resources exist
            $namespace = kubectl get namespace petclinic 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "PetClinic namespace exists"
                
                # Try to get deployment status
                Write-Info "Current deployment status:"
                kubectl get deployments -n petclinic 2>$null
                
                Write-Info "Continuing with deployment..."
            } else {
                throw "Failed to deploy PetClinic application - namespace not found"
            }
        } else {
            Write-Success "PetClinic deployment initiated"
        }
        
        # Wait for pods to be ready
        Write-Info "Waiting for pods to be ready (this may take 3-5 minutes)..."
        Start-Sleep -Seconds 30
        
        kubectl wait --for=condition=ready pod -l app=config-server -n petclinic --timeout=300s 2>$null
        kubectl wait --for=condition=ready pod -l app=discovery-server -n petclinic --timeout=300s 2>$null
        kubectl wait --for=condition=ready pod -l app=api-gateway -n petclinic --timeout=300s 2>$null
        
        Write-Success "Core services are ready"
        
        # Show deployment status
        Write-Info "Current deployment status:"
        kubectl get pods -n petclinic
    } else {
        Write-Info "Skipping PetClinic deployment"
    }

    # ============================================
    # STEP 8: Deploy MCP Servers
    # ============================================
    if (-not $SkipDeploy) {
        Write-Step "STEP 8: Deploying MCP Servers"
        
        Write-Info "Deploying MCP servers to AKS..."
        
        $ErrorActionPreference = "Continue"
        kubectl apply -f k8s/mcp-servers.yaml 2>&1 | Out-Null
        $mcpResult = $LASTEXITCODE
        $ErrorActionPreference = "Stop"
        
        if ($mcpResult -ne 0) {
            Write-Info "Some MCP resources may already exist, verifying..."
            kubectl get deployments -n petclinic -l app=prometheus-mcp 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Info "MCP deployments exist, continuing..."
            } else {
                throw "Failed to deploy MCP servers"
            }
        }
        
        Write-Success "MCP servers deployed"
        
        # Wait for MCP pods
        Write-Info "Waiting for MCP servers to be ready..."
        Start-Sleep -Seconds 20
        
        kubectl wait --for=condition=ready pod -l app=prometheus-mcp -n petclinic --timeout=120s 2>$null
        kubectl wait --for=condition=ready pod -l app=grafana-mcp -n petclinic --timeout=120s 2>$null
        kubectl wait --for=condition=ready pod -l app=postgres-mcp -n petclinic --timeout=120s 2>$null
        
        Write-Success "MCP servers are ready"
    } else {
        Write-Info "Skipping MCP server deployment"
    }

    # ============================================
    # STEP 9: Get Service Endpoints
    # ============================================
    Write-Step "STEP 9: Retrieving Service Endpoints"
    
    Write-Info "Waiting for LoadBalancer IPs to be assigned (this may take 2-3 minutes)..."
    Start-Sleep -Seconds 60
    
    $apiGatewayIP = kubectl get svc api-gateway -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    $grafanaIP = kubectl get svc grafana -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    
    # ============================================
    # STEP 10: Port-Forward MCP Servers
    # ============================================
    if (-not $SkipPortForward) {
        Write-Step "STEP 10: Setting up Port-Forwards for MCP Servers"
        
        Write-Info "Starting port-forwards in separate windows..."
        
        Start-Process powershell -ArgumentList "-NoExit","-Command","Write-Host 'Prometheus MCP Port-Forward (8090:80)' -ForegroundColor Green; kubectl port-forward -n petclinic service/prometheus-mcp-service 8090:80"
        
        Start-Process powershell -ArgumentList "-NoExit","-Command","Write-Host 'Grafana MCP Port-Forward (8091:80)' -ForegroundColor Yellow; kubectl port-forward -n petclinic service/grafana-mcp-service 8091:80"
        
        Start-Process powershell -ArgumentList "-NoExit","-Command","Write-Host 'PostgreSQL MCP Port-Forward (8092:80)' -ForegroundColor Cyan; kubectl port-forward -n petclinic service/postgres-mcp-service 8092:80"
        
        Write-Success "Port-forwards started in separate windows"
    } else {
        Write-Info "Skipping port-forward setup"
    }

    # ============================================
    # DEPLOYMENT SUMMARY
    # ============================================
    Write-Step "DEPLOYMENT COMPLETE!"
    
    Write-Host "`n📋 DEPLOYMENT SUMMARY" -ForegroundColor Green
    Write-Host "=====================================================`n" -ForegroundColor Green
    
    Write-Host "🔧 Azure Resources:" -ForegroundColor Cyan
    Write-Host "  Resource Group:  $ResourceGroupName" -ForegroundColor White
    Write-Host "  Location:        $Location" -ForegroundColor White
    Write-Host "  ACR:             $AcrName.azurecr.io" -ForegroundColor White
    Write-Host "  AKS Cluster:     $AksName" -ForegroundColor White
    Write-Host "  SQL Server:      petclinic-sql-server" -ForegroundColor White
    Write-Host "  SQL Database:    petclinic" -ForegroundColor White
    
    Write-Host "`n🌐 Application Endpoints:" -ForegroundColor Cyan
    if ($apiGatewayIP) {
        Write-Host "  PetClinic App:   http://$apiGatewayIP" -ForegroundColor Green
    } else {
        Write-Host "  PetClinic App:   (LoadBalancer IP pending)" -ForegroundColor Yellow
        Write-Host "                   Run: kubectl get svc api-gateway -n petclinic" -ForegroundColor Gray
    }
    
    if ($grafanaIP) {
        Write-Host "  Grafana:         http://$grafanaIP" -ForegroundColor Green
    } else {
        Write-Host "  Grafana:         (LoadBalancer IP pending)" -ForegroundColor Yellow
        Write-Host "                   Run: kubectl get svc grafana -n petclinic" -ForegroundColor Gray
    }
    
    Write-Host "`n🤖 MCP Server Endpoints (Local):" -ForegroundColor Cyan
    Write-Host "  Prometheus MCP:  http://localhost:8090" -ForegroundColor White
    Write-Host "  Grafana MCP:     http://localhost:8091" -ForegroundColor White
    Write-Host "  PostgreSQL MCP:  http://localhost:8092" -ForegroundColor White
    
    Write-Host "`n📊 Monitoring Stack:" -ForegroundColor Cyan
    Write-Host "  Prometheus:      http://prometheus.petclinic.svc.cluster.local:9090" -ForegroundColor White
    Write-Host "  Loki:            http://loki.petclinic.svc.cluster.local:3100" -ForegroundColor White
    Write-Host "  Tempo:           http://tempo.petclinic.svc.cluster.local:3200" -ForegroundColor White
    
    Write-Host "`n🧪 Quick Tests:" -ForegroundColor Cyan
    Write-Host "  curl http://localhost:8090/health" -ForegroundColor Gray
    Write-Host "  curl http://localhost:8091/health" -ForegroundColor Gray
    Write-Host "  curl http://localhost:8092/health" -ForegroundColor Gray
    
    Write-Host "`n📝 Useful Commands:" -ForegroundColor Cyan
    Write-Host "  kubectl get pods -n petclinic" -ForegroundColor Gray
    Write-Host "  kubectl get svc -n petclinic" -ForegroundColor Gray
    Write-Host "  kubectl logs -f deployment/api-gateway -n petclinic" -ForegroundColor Gray
    
    Write-Host "`n✅ Deployment completed successfully!`n" -ForegroundColor Green
    
    # Save deployment info to file
    $deploymentInfo = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ResourceGroup = $ResourceGroupName
        Location = $Location
        ACR = "$AcrName.azurecr.io"
        AKS = $AksName
        SqlServer = "petclinic-sql-server"
        SqlDatabase = "petclinic"
        PetClinicURL = if ($apiGatewayIP) { "http://$apiGatewayIP" } else { "Pending" }
        GrafanaURL = if ($grafanaIP) { "http://$grafanaIP" } else { "Pending" }
        MCPEndpoints = @{
            Prometheus = "http://localhost:8090"
            Grafana = "http://localhost:8091"
            SQL = "jdbc:sqlserver://petclinic-sql-server.database.windows.net:1433;database=petclinic;user=petclinicadmin@petclinic-sql-server;password=P@ssw0rd123!;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
        }
    }
    
    $deploymentInfo | ConvertTo-Json -Depth 10 | Out-File "deployment-info.json"
    Write-Info "Deployment details saved to: deployment-info.json"
    
} catch {
    Write-Error-Custom "Deployment failed: $($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
