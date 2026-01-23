# Complete Azure Infrastructure Deployment Guide

This guide explains how to use the automated deployment script to deploy the entire PetClinic application with observability and MCP servers on Azure.

## 📋 Overview

The `deploy-complete-azure-infrastructure.ps1` script automates the complete deployment process:

1. **Azure Login** - Authenticate to Azure
2. **Resource Group** - Create resource group
3. **ACR** - Create Azure Container Registry
4. **AKS** - Create Azure Kubernetes Service cluster
5. **PostgreSQL** - Create Azure Database for PostgreSQL
6. **Build & Push** - Build and push Docker images
7. **Deploy App** - Deploy PetClinic with observability
8. **Deploy MCP** - Deploy MCP servers
9. **Port-Forward** - Set up local access to MCP servers

## 🚀 Quick Start

### Basic Usage (Full Deployment)

```powershell
.\deploy-complete-azure-infrastructure.ps1
```

This will deploy everything with default settings:
- Resource Group: `petclinic-rg`
- Location: `eastus`
- ACR: `petclinicdemo1234`
- AKS: `petclinic-aks` (3 nodes, Standard_DS2_v2)
- PostgreSQL: `petclinic-postgres-server`

### Custom Configuration

```powershell
.\deploy-complete-azure-infrastructure.ps1 `
    -ResourceGroupName "my-petclinic-rg" `
    -Location "westus2" `
    -AcrName "mypetclinicacr" `
    -AksName "my-aks-cluster" `
    -PostgresServerName "my-postgres-server" `
    -AksNodeCount 5 `
    -AksNodeSize "Standard_D4s_v3"
```

## 📝 Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `ResourceGroupName` | Azure resource group name | `petclinic-rg` | No |
| `Location` | Azure region | `eastus` | No |
| `AcrName` | Container registry name (globally unique) | `petclinicdemo1234` | No |
| `AksName` | Kubernetes cluster name | `petclinic-aks` | No |
| `PostgresServerName` | PostgreSQL server name (globally unique) | `petclinic-postgres-server` | No |
| `PostgresAdminUser` | PostgreSQL admin username | `petclinicadmin` | No |
| `PostgresAdminPassword` | PostgreSQL admin password | `P@ssw0rd123!` | No |
| `PostgresDatabase` | Database name | `petclinic` | No |
| `AksNodeCount` | Number of AKS nodes | `3` | No |
| `AksNodeSize` | AKS node VM size | `Standard_DS2_v2` | No |

### Skip Flags

Use these flags to skip certain steps (useful for partial deployments or testing):

| Flag | Description |
|------|-------------|
| `-SkipLogin` | Skip Azure login (if already logged in) |
| `-SkipResourceCreation` | Skip creating Azure resources (RG, ACR, AKS, PostgreSQL) |
| `-SkipBuild` | Skip building and pushing Docker images |
| `-SkipDeploy` | Skip deploying applications to AKS |
| `-SkipPortForward` | Skip setting up port-forwards |

### Example: Re-deploy Application Only

```powershell
# If infrastructure exists, just rebuild and redeploy
.\deploy-complete-azure-infrastructure.ps1 `
    -SkipLogin `
    -SkipResourceCreation
```

### Example: Deploy Infrastructure Only

```powershell
# Create infrastructure without deploying applications
.\deploy-complete-azure-infrastructure.ps1 `
    -SkipBuild `
    -SkipDeploy `
    -SkipPortForward
```

## 🏗️ What Gets Deployed

### Azure Resources

1. **Resource Group**
   - Contains all resources
   - Location: Configurable (default: eastus)

2. **Azure Container Registry (ACR)**
   - SKU: Basic
   - Admin enabled
   - Stores all Docker images

3. **Azure Kubernetes Service (AKS)**
   - Node count: Configurable (default: 3)
   - VM size: Configurable (default: Standard_DS2_v2)
   - Monitoring: Enabled
   - ACR integration: Automatic

4. **Azure Database for PostgreSQL**
   - Version: 15
   - Tier: Burstable
   - SKU: Standard_B1ms
   - Storage: 32 GB
   - Public access: Enabled (0.0.0.0-255.255.255.255)

### Kubernetes Workloads

#### PetClinic Microservices (7 services)
- `config-server` - Centralized configuration
- `discovery-server` - Service registry (Eureka)
- `api-gateway` - API Gateway (LoadBalancer)
- `customers-service` - Customer management
- `vets-service` - Veterinarian management
- `visits-service` - Visit records
- `admin-server` - Admin dashboard

#### Observability Stack
- **Prometheus** - Metrics collection (ClusterIP)
- **Grafana** - Dashboards and visualization (LoadBalancer)
- **Loki** - Log aggregation (ClusterIP)
- **Tempo** - Distributed tracing (ClusterIP)
- **OpenTelemetry Collector** - Telemetry pipeline (ClusterIP)

#### Database
- **PostgreSQL StatefulSet** - Database with persistent storage (10Gi)

#### MCP Servers (6 pods - 2 replicas each)
- **Prometheus MCP** - AI integration with Prometheus (NodePort: 30090)
- **Grafana MCP** - AI integration with Grafana (NodePort: 30091)
- **PostgreSQL MCP** - AI integration with PostgreSQL (NodePort: 30092)

## ⏱️ Deployment Timeline

| Step | Estimated Time |
|------|----------------|
| Azure Login | 30 seconds |
| Create Resource Group | 10 seconds |
| Create ACR | 1-2 minutes |
| Create AKS | 10-15 minutes |
| Create PostgreSQL | 5-10 minutes |
| Build & Push Images | 10-15 minutes |
| Deploy Applications | 3-5 minutes |
| Deploy MCP Servers | 1-2 minutes |
| Port-Forward Setup | 10 seconds |
| **Total** | **30-50 minutes** |

## 📊 Post-Deployment Access

### Application URLs

After deployment completes, access your services:

```powershell
# Get API Gateway IP
kubectl get svc api-gateway -n petclinic

# Get Grafana IP
kubectl get svc grafana -n petclinic
```

**PetClinic Application:**
- URL: `http://<API_GATEWAY_IP>`
- Swagger UI: `http://<API_GATEWAY_IP>/swagger-ui.html`

**Grafana Dashboards:**
- URL: `http://<GRAFANA_IP>`
- Default credentials: admin/admin

### MCP Server Endpoints (Local)

MCP servers are automatically port-forwarded:

- **Prometheus MCP**: `http://localhost:8090`
- **Grafana MCP**: `http://localhost:8091`
- **PostgreSQL MCP**: `http://localhost:8092`

Test health endpoints:
```powershell
curl http://localhost:8090/health
curl http://localhost:8091/health
curl http://localhost:8092/health
```

### Internal Services (Cluster)

- **Prometheus**: `http://prometheus.petclinic.svc.cluster.local:9090`
- **Loki**: `http://loki.petclinic.svc.cluster.local:3100`
- **Tempo**: `http://tempo.petclinic.svc.cluster.local:3200`
- **PostgreSQL**: `postgres-0.postgres.petclinic.svc.cluster.local:5432`

## 🔍 Verification Commands

### Check All Pods
```powershell
kubectl get pods -n petclinic
```

Expected output: 19+ pods in Running state

### Check Services
```powershell
kubectl get svc -n petclinic
```

### Check MCP Servers
```powershell
kubectl get pods,svc -n petclinic | Select-String "mcp"
```

### View Logs
```powershell
# API Gateway logs
kubectl logs -f deployment/api-gateway -n petclinic

# Prometheus MCP logs
kubectl logs -f deployment/prometheus-mcp -n petclinic

# PostgreSQL logs
kubectl logs -f statefulset/postgres -n petclinic
```

## 🛠️ Troubleshooting

### Issue: ACR Name Already Exists

ACR names must be globally unique. If you get an error:

```powershell
.\deploy-complete-azure-infrastructure.ps1 -AcrName "myuniquename123"
```

### Issue: AKS Creation Timeout

AKS creation can take up to 20 minutes in some regions. Be patient.

### Issue: LoadBalancer IP Not Assigned

Wait a few minutes and check:
```powershell
kubectl get svc api-gateway -n petclinic --watch
```

### Issue: Pods in CrashLoopBackOff

Check logs for specific pod:
```powershell
kubectl logs pod/<POD_NAME> -n petclinic
kubectl describe pod/<POD_NAME> -n petclinic
```

### Issue: Port-Forward Already in Use

Kill existing port-forwards:
```powershell
Get-Process -Name kubectl | Where-Object {$_.CommandLine -like "*port-forward*"} | Stop-Process
```

## 🔄 Re-running the Script

### Update Application Code Only

```powershell
.\deploy-complete-azure-infrastructure.ps1 `
    -SkipLogin `
    -SkipResourceCreation
```

### Rebuild Images Only

```powershell
# Make code changes, then:
mvn clean install -DskipTests

# Build and push new images
az acr login --name petclinicdemo1234
docker build -t petclinicdemo1234.azurecr.io/spring-petclinic-customers-service:latest ./spring-petclinic-customers-service
docker push petclinicdemo1234.azurecr.io/spring-petclinic-customers-service:latest

# Restart deployment
kubectl rollout restart deployment/customers-service -n petclinic
```

## 🧹 Cleanup

### Delete Everything

```powershell
# Delete entire resource group (this deletes all resources)
az group delete --name petclinic-rg --yes --no-wait
```

### Delete Kubernetes Resources Only

```powershell
kubectl delete namespace petclinic
```

### Stop Port-Forwards

Close the PowerShell windows or:
```powershell
Get-Process -Name kubectl | Stop-Process -Force
```

## 📈 Monitoring and Observability

### Prometheus Queries

Access Prometheus UI (via port-forward or Grafana):
```
# CPU usage
container_cpu_usage_seconds_total

# Memory usage
container_memory_usage_bytes

# HTTP requests
http_server_requests_seconds_count
```

### Grafana Dashboards

Pre-configured dashboards available:
- **Spring Boot 2.1 Statistics**: Application metrics
- **Kubernetes Cluster Monitoring**: Cluster health
- **JVM Dashboard**: Java metrics

### Loki Log Queries

Query logs via Grafana:
```
{namespace="petclinic", app="customers-service"}
```

## 🤖 MCP Server Usage

### Connect from Claude Desktop

Add to `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "prometheus": {
      "url": "http://localhost:8090/mcp"
    },
    "grafana": {
      "url": "http://localhost:8091/mcp"
    },
    "postgres": {
      "url": "http://localhost:8092/mcp"
    }
  }
}
```

### Connect from Python

```python
import requests

# Query Prometheus metrics
response = requests.post(
    "http://localhost:8090/mcp",
    json={
        "jsonrpc": "2.0",
        "method": "tools/list",
        "params": {},
        "id": 1
    }
)

print(response.json())
```

## 📚 Additional Resources

- **PetClinic Documentation**: See [README.md](README.md)
- **MCP Server Guide**: See [MCP-SERVERS-GUIDE.md](MCP-SERVERS-GUIDE.md)
- **Deployment Summary**: Generated as `deployment-info.json`
- **Azure AKS Docs**: https://learn.microsoft.com/azure/aks/
- **Prometheus Docs**: https://prometheus.io/docs/
- **Grafana Docs**: https://grafana.com/docs/

## 💡 Best Practices

1. **Use Strong Passwords**: Change default PostgreSQL password in production
2. **Resource Sizing**: Adjust AKS node size based on workload
3. **Cost Management**: Use Basic tier for ACR in dev/test environments
4. **Backup Database**: Enable automated backups for PostgreSQL
5. **Monitor Costs**: Use Azure Cost Management to track spending
6. **Security**: Restrict PostgreSQL public access in production
7. **Version Control**: Commit `deployment-info.json` to track deployments

## 🎯 Success Criteria

Deployment is successful when:

✅ All 19+ pods are in `Running` state  
✅ API Gateway has external IP assigned  
✅ Grafana has external IP assigned  
✅ MCP servers respond to health checks  
✅ PetClinic UI is accessible  
✅ Grafana dashboards display metrics  
✅ `deployment-info.json` is created  

---

**Script Location**: `deploy-complete-azure-infrastructure.ps1`  
**Last Updated**: January 23, 2026  
**Version**: 1.0
