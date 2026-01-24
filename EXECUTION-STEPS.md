# PetClinic on Azure - Quick Execution Steps

> **Complete automated deployment of PetClinic microservices application with observability stack and MCP servers on Azure Kubernetes Service**

## ⚡ Quick Start - 3 Simple Steps

### Prerequisites Checklist

Before starting, ensure you have:

- ✅ **Azure Subscription** - Active Azure account
- ✅ **Azure CLI** - Installed and updated ([Download](https://learn.microsoft.com/cli/azure/install-azure-cli))
- ✅ **kubectl** - Kubernetes CLI ([Download](https://kubernetes.io/docs/tasks/tools/))
- ✅ **Docker Desktop** - Running on Windows ([Download](https://www.docker.com/products/docker-desktop))
- ✅ **Java 17** - JDK installed
- ✅ **Maven** - Build tool installed
- ✅ **PowerShell** - Windows PowerShell 5.1 or later
- ✅ **Git** - For version control

### Verify Prerequisites

```powershell
# Check Azure CLI
az --version

# Check kubectl
kubectl version --client

# Check Docker
docker --version

# Check Java
java -version

# Check Maven
mvn --version
```

---

## 🚀 STEP 1: Run the Deployment Script

Open PowerShell and navigate to the project directory:

```powershell
cd "D:\SRE Activity\CapG_Assets\Working\cloud-sre-demo-applications\spring-petclinic-microservices"
```

### Option A: Full Deployment with Defaults

```powershell
.\deploy-complete-azure-infrastructure.ps1
```

**This will create:**
- Resource Group: `petclinic-rg`
- Location: `eastus`
- ACR: `petclinicdemo1234`
- AKS: `petclinic-aks` (3 nodes)
- PostgreSQL: `petclinic-postgres-db`

### Option B: Custom Configuration

```powershell
.\deploy-complete-azure-infrastructure.ps1 `
    -ResourceGroupName "my-petclinic-rg" `
    -Location "westus2" `
    -AcrName "myuniquename123" `
    -AksName "my-aks-cluster" `
    -PostgresServerName "my-postgres-db" `
    -AksNodeCount 5 `
    -AksNodeSize "Standard_D4s_v3"
```

**⏱️ Expected Duration:** 30-50 minutes

The script will automatically:
1. Log into Azure *(30 seconds)*
2. Create Resource Group *(10 seconds)*
3. Create Azure Container Registry *(1-2 minutes)*
4. Create AKS Cluster *(10-15 minutes)*
5. Create PostgreSQL Database *(5-10 minutes)*
6. Build & Push Docker Images *(10-15 minutes)*
7. Deploy PetClinic Application *(3-5 minutes)*
8. Deploy MCP Servers *(1-2 minutes)*
9. Setup Port-Forwards *(10 seconds)*

### What Happens During Deployment?

You'll see colored output showing progress:

- 🟦 **Cyan** - Step headers
- 🟩 **Green** - Success messages
- 🟨 **Yellow** - Information messages
- 🟥 **Red** - Error messages

---

## 📊 STEP 2: Monitor Deployment Progress

### Watch Pod Status

Open a second PowerShell window:

```powershell
# Watch pods coming up
kubectl get pods -n petclinic --watch
```

**Expected Output:**
```
NAME                                 READY   STATUS    RESTARTS   AGE
config-server-xxx                    1/1     Running   0          2m
discovery-server-xxx                 1/1     Running   0          2m
api-gateway-xxx                      1/1     Running   0          3m
customers-service-xxx                1/1     Running   0          3m
vets-service-xxx                     1/1     Running   0          3m
visits-service-xxx                   1/1     Running   0          3m
admin-server-xxx                     1/1     Running   0          2m
prometheus-xxx                       1/1     Running   0          3m
grafana-xxx                          1/1     Running   0          3m
loki-xxx                             1/1     Running   0          3m
tempo-xxx                            1/1     Running   0          3m
otel-collector-xxx                   1/1     Running   0          3m
postgres-0                           1/1     Running   0          4m
prometheus-mcp-xxx                   1/1     Running   0          1m
grafana-mcp-xxx                      1/1     Running   0          1m
postgres-mcp-xxx                     1/1     Running   0          1m
```

**Total Pods:** 19+ (all should be "Running")

### Check Services

```powershell
kubectl get svc -n petclinic
```

**Look for:**
- `api-gateway` - LoadBalancer with EXTERNAL-IP
- `grafana` - LoadBalancer with EXTERNAL-IP
- MCP services - NodePort type

---

## 🌐 STEP 3: Access the Applications

### Wait for LoadBalancer IPs

It may take 2-3 minutes for Azure to assign external IPs:

```powershell
# Watch until EXTERNAL-IP appears (not <pending>)
kubectl get svc api-gateway grafana -n petclinic --watch
```

### Get Access URLs

```powershell
# Get PetClinic URL
$PETCLINIC_IP = kubectl get svc api-gateway -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "PetClinic App: http://$PETCLINIC_IP" -ForegroundColor Green

# Get Grafana URL
$GRAFANA_IP = kubectl get svc grafana -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "Grafana: http://$GRAFANA_IP" -ForegroundColor Green
```

### Open in Browser

**PetClinic Application:**
```
http://<API_GATEWAY_IP>
```

**Grafana Dashboards:**
```
http://<GRAFANA_IP>
```
- Username: `admin`
- Password: `admin`

### Access MCP Servers (Local)

The deployment script automatically opens 3 PowerShell windows with port-forwards:

**MCP Endpoints:**
- **Prometheus MCP:** http://localhost:8090
- **Grafana MCP:** http://localhost:8091
- **PostgreSQL MCP:** http://localhost:8092

**Test Health:**
```powershell
curl http://localhost:8090/health
curl http://localhost:8091/health
curl http://localhost:8092/health
```

---

## ✅ Verification Checklist

### 1. Check All Pods Running

```powershell
kubectl get pods -n petclinic
```

✅ All pods should show `1/1` in READY column and `Running` status

### 2. Check Services

```powershell
kubectl get svc -n petclinic
```

✅ `api-gateway` and `grafana` should have EXTERNAL-IP (not `<pending>`)

### 3. Test PetClinic UI

Open browser: `http://<API_GATEWAY_IP>`

✅ Should see PetClinic home page with navigation menu

### 4. Test Grafana

Open browser: `http://<GRAFANA_IP>`

✅ Login successful, dashboards visible

### 5. Test MCP Health

```powershell
curl http://localhost:8090/health
curl http://localhost:8091/health
curl http://localhost:8092/health
```

✅ Each should return `{"status":"ok"}`

### 6. Check Deployment Info

```powershell
cat deployment-info.json
```

✅ File exists with all deployment details

---

## 🧪 Post-Deployment Testing

### Test PetClinic Functionality

1. **View Owners:**
   - Click "OWNERS" → "ALL"
   - Should see list of pet owners

2. **View Veterinarians:**
   - Click "VETERINARIANS"
   - Should see list of vets

3. **Add New Owner:**
   - Click "OWNERS" → "REGISTER"
   - Fill form and submit
   - Verify owner appears in list

### Test Observability Stack

**Prometheus Queries:**

```powershell
# Port-forward Prometheus (if not already)
kubectl port-forward -n petclinic svc/prometheus 9090:9090
```

Open: http://localhost:9090

Sample queries:
```
# HTTP requests
http_server_requests_seconds_count

# CPU usage
container_cpu_usage_seconds_total{namespace="petclinic"}

# Memory usage
container_memory_usage_bytes{namespace="petclinic"}
```

**Grafana Dashboards:**

Open: `http://<GRAFANA_IP>`

Navigate to:
- **Dashboards** → **Spring Boot Statistics**
- **Dashboards** → **Kubernetes Cluster Monitoring**

### Test MCP Servers

**Query Prometheus MCP:**
```powershell
$body = @{
    jsonrpc = "2.0"
    method = "tools/list"
    params = @{}
    id = 1
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8090/mcp" -Method Post -Body $body -ContentType "application/json"
```

---

## 📝 Common Tasks

### View Logs

```powershell
# API Gateway logs
kubectl logs -f deployment/api-gateway -n petclinic

# Customers service logs
kubectl logs -f deployment/customers-service -n petclinic

# Prometheus MCP logs
kubectl logs -f deployment/prometheus-mcp -n petclinic

# Database logs
kubectl logs -f statefulset/postgres -n petclinic
```

### Restart a Service

```powershell
kubectl rollout restart deployment/customers-service -n petclinic
```

### Scale a Service

```powershell
kubectl scale deployment/customers-service --replicas=3 -n petclinic
```

### Update an Image

```powershell
# After rebuilding and pushing to ACR
kubectl set image deployment/customers-service `
    customers-service=petclinicdemo1234.azurecr.io/spring-petclinic-customers-service:latest `
    -n petclinic
```

---

## 🔧 Troubleshooting

### Issue: Pods Not Starting

**Check pod status:**
```powershell
kubectl describe pod <POD_NAME> -n petclinic
```

**Check logs:**
```powershell
kubectl logs <POD_NAME> -n petclinic
```

**Common fixes:**
- Wait longer (some services take 2-3 minutes)
- Check image pull succeeded
- Verify resource limits

### Issue: LoadBalancer IP Pending

**Wait longer:**
```powershell
kubectl get svc api-gateway -n petclinic --watch
```

**If stuck after 5 minutes:**
```powershell
# Check events
kubectl describe svc api-gateway -n petclinic
```

### Issue: Database Connection Errors

**Check PostgreSQL pod:**
```powershell
kubectl get pods -n petclinic | Select-String postgres
kubectl logs statefulset/postgres -n petclinic
```

**Verify connection from service:**
```powershell
kubectl exec -it deployment/customers-service -n petclinic -- env | grep SPRING_DATASOURCE
```

### Issue: MCP Port-Forward Failed

**Restart port-forwards:**
```powershell
# Kill existing
Get-Process -Name kubectl | Where-Object {$_.CommandLine -like "*port-forward*"} | Stop-Process

# Restart
kubectl port-forward -n petclinic service/prometheus-mcp-service 8090:80
kubectl port-forward -n petclinic service/grafana-mcp-service 8091:80
kubectl port-forward -n petclinic service/postgres-mcp-service 8092:80
```

### Issue: Build Failed

**Check Maven:**
```powershell
mvn --version
java -version
```

**Clean rebuild:**
```powershell
mvn clean install -DskipTests
```

---

## 🧹 Cleanup

### Delete Everything

```powershell
# Delete entire resource group (all resources)
az group delete --name petclinic-rg --yes --no-wait
```

**This removes:**
- AKS cluster
- ACR
- PostgreSQL database
- All deployed applications
- All data

### Delete Kubernetes Resources Only

```powershell
# Keep infrastructure, delete applications
kubectl delete namespace petclinic
```

### Stop Port-Forwards

```powershell
# Close PowerShell windows or:
Get-Process -Name kubectl | Stop-Process -Force
```

---

## 📚 What Was Deployed?

### Azure Infrastructure

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `petclinic-rg` | Container for all resources |
| ACR | `petclinicdemo1234.azurecr.io` | Docker image registry |
| AKS | `petclinic-aks` | Kubernetes cluster (3 nodes) |
| PostgreSQL | `petclinic-postgres-db` | Managed database |

### Kubernetes Workloads

| Component | Replicas | Type | Access |
|-----------|----------|------|--------|
| config-server | 1 | ClusterIP | Internal |
| discovery-server | 1 | ClusterIP | Internal |
| api-gateway | 1 | LoadBalancer | External |
| customers-service | 1 | ClusterIP | Internal |
| vets-service | 1 | ClusterIP | Internal |
| visits-service | 1 | ClusterIP | Internal |
| admin-server | 1 | ClusterIP | Internal |
| prometheus | 1 | ClusterIP | Internal |
| grafana | 1 | LoadBalancer | External |
| loki | 1 | ClusterIP | Internal |
| tempo | 1 | ClusterIP | Internal |
| otel-collector | 1 | ClusterIP | Internal |
| postgres | 1 | StatefulSet | Internal |
| prometheus-mcp | 2 | NodePort | Port-forward |
| grafana-mcp | 2 | NodePort | Port-forward |
| postgres-mcp | 2 | NodePort | Port-forward |

**Total:** 19+ pods across petclinic namespace

---

## 🎯 Success Criteria

Your deployment is successful when:

✅ All pods show `Running` status  
✅ API Gateway has external IP  
✅ Grafana has external IP  
✅ PetClinic UI loads in browser  
✅ Grafana dashboards accessible  
✅ MCP servers respond to health checks  
✅ Can add/view owners and vets  
✅ Metrics visible in Prometheus  
✅ `deployment-info.json` created  

---

## 📞 Next Steps

### Explore the Application

1. **Browse PetClinic** - Add owners, pets, and visits
2. **View Metrics** - Check Grafana dashboards
3. **Query Logs** - Use Loki for log analysis
4. **Trace Requests** - View distributed traces in Tempo

### Connect AI Tools

Use MCP servers to integrate AI tools:

**Claude Desktop Integration:**
See [MCP-SERVERS-GUIDE.md](MCP-SERVERS-GUIDE.md)

**Python Integration:**
```python
import requests
response = requests.post("http://localhost:8090/mcp", json={...})
```

### Customize Deployment

- Scale services: Increase replicas
- Add monitoring: Custom Grafana dashboards
- Update code: Rebuild and redeploy services
- Configure alerts: Prometheus alerting rules

---

## 📖 Additional Documentation

- **[COMPLETE-INFRASTRUCTURE-DEPLOYMENT-README.md](COMPLETE-INFRASTRUCTURE-DEPLOYMENT-README.md)** - Comprehensive deployment guide with all parameters
- **[MCP-SERVERS-GUIDE.md](MCP-SERVERS-GUIDE.md)** - MCP server usage and integration
- **[PETCLINIC-DEPLOYMENT-SUMMARY.md](PETCLINIC-DEPLOYMENT-SUMMARY.md)** - Deployment architecture overview
- **[README.md](README.md)** - Project overview

---

## ⚡ Quick Reference

```powershell
# Deploy everything
.\deploy-complete-azure-infrastructure.ps1

# Check status
kubectl get pods -n petclinic

# Get URLs
kubectl get svc api-gateway grafana -n petclinic

# View logs
kubectl logs -f deployment/api-gateway -n petclinic

# Test MCP
curl http://localhost:8090/health

# Delete all
az group delete --name petclinic-rg --yes
```

---

**Deployment Script:** `deploy-complete-azure-infrastructure.ps1`  
**Estimated Time:** 30-50 minutes  
**Total Cost:** ~$5-10/day (Azure resources)  
**Support:** Check logs with `kubectl logs` and `kubectl describe`
