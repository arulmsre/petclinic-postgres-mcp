# PostgreSQL MCP Server - AKS Deployment Complete

## 🎉 Deployment Summary

The PostgreSQL MCP server has been successfully deployed to AKS, matching the deployment pattern of Prometheus and Grafana MCP servers.

### Deployment Details

- **Image**: `petclinicdemo1234.azurecr.io/postgres-mcp-http:latest`
- **Namespace**: `petclinic`
- **Replicas**: 2 pods
- **Service**: `postgres-mcp-service` (NodePort 30092)
- **Health Endpoints**: `/health` on port 3000

### PostgreSQL Connection Configuration

The MCP server connects to the PostgreSQL database using cluster-internal service name:

```yaml
PG_HOST: postgres.petclinic.svc.cluster.local
PG_PORT: 5432
PG_DATABASE: petclinic
PG_USER: petclinic
PG_PASSWORD: [from secret: postgres-mcp-secrets]
PG_SSL: false
```

## 🚀 All MCP Servers Now Running in AKS

All three MCP servers are now deployed to AKS with consistent configuration:

| MCP Server | Image | Service | NodePort | Port Forward |
|-----------|-------|---------|----------|--------------|
| Prometheus | prometheus-mcp-http:latest | prometheus-mcp-service | 30090 | 8090:80 |
| Grafana | grafana-mcp-http:latest | grafana-mcp-service | 30091 | 8091:80 |
| **PostgreSQL** | **postgres-mcp-http:latest** | **postgres-mcp-service** | **30092** | **8092:80** |

## 📋 Updated Port-Forward Commands

### All-in-One Command (Open 4 PowerShell Windows)

**Window 1: PostgreSQL Database**
```powershell
kubectl port-forward service/postgres -n petclinic 5433:5432
```

**Window 2: Prometheus MCP**
```powershell
kubectl port-forward service/prometheus-mcp-service -n petclinic 8090:80
```

**Window 3: Grafana MCP**
```powershell
kubectl port-forward service/grafana-mcp-service -n petclinic 8091:80
```

**Window 4: PostgreSQL MCP** ✨ **NEW - Now from AKS!**
```powershell
kubectl port-forward service/postgres-mcp-service -n petclinic 8092:80
```

### PowerShell Script Version

Save as `start-all-mcp-aks.ps1`:

```powershell
# Start all MCP servers from AKS with port-forwarding
# All MCP servers now running in Kubernetes!

# PostgreSQL Database
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward service/postgres -n petclinic 5433:5432"
Start-Sleep -Seconds 2

# Prometheus MCP (from AKS)
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward service/prometheus-mcp-service -n petclinic 8090:80"
Start-Sleep -Seconds 2

# Grafana MCP (from AKS)
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward service/grafana-mcp-service -n petclinic 8091:80"
Start-Sleep -Seconds 2

# PostgreSQL MCP (from AKS) - NEW!
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward service/postgres-mcp-service -n petclinic 8092:80"

Write-Host "`n✅ All MCP servers are starting from AKS!" -ForegroundColor Green
Write-Host "📡 MCP Endpoints:" -ForegroundColor Cyan
Write-Host "  - Prometheus MCP: http://localhost:8090" -ForegroundColor White
Write-Host "  - Grafana MCP:    http://localhost:8091" -ForegroundColor White
Write-Host "  - PostgreSQL MCP: http://localhost:8092" -ForegroundColor Yellow
Write-Host "`n🗄️  PostgreSQL DB: localhost:5433" -ForegroundColor White
Write-Host "`nAll servers are now running in AKS with 2 replicas each!" -ForegroundColor Green
```

## 🔍 Verify Deployment

### Check Pod Status
```powershell
kubectl get pods -n petclinic | Select-String "mcp"
```

Expected output:
```
prometheus-mcp-xxxxx-xxxxx   1/1     Running   0          Xm
prometheus-mcp-xxxxx-xxxxx   1/1     Running   0          Xm
grafana-mcp-xxxxx-xxxxx      1/1     Running   0          Xm
grafana-mcp-xxxxx-xxxxx      1/1     Running   0          Xm
postgres-mcp-xxxxx-xxxxx     1/1     Running   0          Xm
postgres-mcp-xxxxx-xxxxx     1/1     Running   0          Xm
```

### Check Services
```powershell
kubectl get svc -n petclinic | Select-String "mcp"
```

Expected output:
```
prometheus-mcp-service   NodePort    10.x.x.x   <none>   80:30090/TCP   Xm
grafana-mcp-service      NodePort    10.x.x.x   <none>   80:30091/TCP   Xm
postgres-mcp-service     NodePort    10.x.x.x   <none>   80:30092/TCP   Xm
```

### Health Check All MCP Servers

After setting up port-forwards:

```powershell
# Prometheus MCP
Invoke-RestMethod http://localhost:8090/health

# Grafana MCP
Invoke-RestMethod http://localhost:8091/health

# PostgreSQL MCP (NEW!)
Invoke-RestMethod http://localhost:8092/health
```

All should return:
```json
{"status":"ok","server":"mcp-http-bridge"}
```

### Test PostgreSQL MCP Tools

```powershell
$body = @{
    method = "tools/list"
} | ConvertTo-Json

Invoke-RestMethod -Uri http://localhost:8092/message -Method Post -Body $body -ContentType "application/json"
```

Expected: List of PostgreSQL tools (query, listTables, describeTable, etc.)

### Test PostgreSQL MCP Query

```powershell
$body = @{
    method = "tools/call"
    params = @{
        name = "query"
        arguments = @{
            query = "SELECT * FROM vets LIMIT 5"
        }
    }
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri http://localhost:8092/message -Method Post -Body $body -ContentType "application/json"
```

## 🏗️ Architecture Benefits

### Before (Mixed Deployment)
- ❌ Prometheus MCP: AKS (2 replicas)
- ❌ Grafana MCP: AKS (2 replicas)
- ❌ PostgreSQL MCP: **Local Node.js process**

**Issues:**
- Inconsistent deployment pattern
- Manual Node.js process management
- No high availability for PostgreSQL MCP
- Different startup procedures

### After (Unified AKS Deployment) ✅
- ✅ Prometheus MCP: AKS (2 replicas)
- ✅ Grafana MCP: AKS (2 replicas)
- ✅ PostgreSQL MCP: **AKS (2 replicas)**

**Benefits:**
- 🎯 Consistent deployment pattern
- 🔄 High availability (2 replicas per MCP)
- 📈 Kubernetes-native scaling
- 🛡️ Health checks and auto-restart
- 🚀 Simplified startup (just port-forwards)
- 📦 All images in ACR

## 📊 Resource Allocation

Each MCP pod has:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Total Resource Usage:**
- 6 MCP pods × 100m CPU = 600m CPU requested
- 6 MCP pods × 128Mi memory = 768Mi memory requested

## 🔐 Security Notes

### Secrets Management
Passwords are stored in Kubernetes Secrets:

```yaml
# PostgreSQL MCP credentials
apiVersion: v1
kind: Secret
metadata:
  name: postgres-mcp-secrets
  namespace: petclinic
type: Opaque
stringData:
  password: "petclinic"  # Change in production!
```

**Production Recommendations:**
1. Use Azure Key Vault with CSI driver
2. Rotate passwords regularly
3. Use managed identity for ACR access
4. Enable network policies

## 🚢 Docker Image Details

### Multi-Stage Build
The Dockerfile uses 3 stages:

1. **mcp-server-builder**: Build PostgreSQL MCP TypeScript
2. **bridge-builder**: Build HTTP bridge TypeScript
3. **production**: Combine both, run as non-root user

### Image Layers
```
petclinicdemo1234.azurecr.io/postgres-mcp-http:latest
├── Node.js 20-alpine (base)
├── MCP Server (postgres-mcp-server/dist)
├── HTTP Bridge (mcp-http-bridge/dist)
└── Non-root user (nodejs:1001)
```

### Build Command
```powershell
docker build -t arul1985/postgres-mcp-http:latest -f Dockerfile.postgres-http .
docker tag arul1985/postgres-mcp-http:latest petclinicdemo1234.azurecr.io/postgres-mcp-http:latest
docker push petclinicdemo1234.azurecr.io/postgres-mcp-http:latest
```

## 📝 Rollout and Updates

### Update Image
```powershell
# Build new version
docker build -t petclinicdemo1234.azurecr.io/postgres-mcp-http:v2 -f Dockerfile.postgres-http .
docker push petclinicdemo1234.azurecr.io/postgres-mcp-http:v2

# Update deployment
kubectl set image deployment/postgres-mcp postgres-mcp=petclinicdemo1234.azurecr.io/postgres-mcp-http:v2 -n petclinic

# Check rollout status
kubectl rollout status deployment/postgres-mcp -n petclinic
```

### Rollback
```powershell
kubectl rollout undo deployment/postgres-mcp -n petclinic
```

### Scale Replicas
```powershell
# Scale up
kubectl scale deployment/postgres-mcp --replicas=3 -n petclinic

# Scale down
kubectl scale deployment/postgres-mcp --replicas=1 -n petclinic
```

## 🧪 Testing Checklist

- [x] Docker image builds successfully
- [x] Image pushed to ACR
- [x] Deployment created in AKS
- [x] 2 pods running and healthy
- [x] Service exposed on NodePort 30092
- [x] Port-forward works (8092:80)
- [x] Health endpoint responds
- [x] PostgreSQL MCP tools listed
- [x] Database queries execute successfully
- [x] Consistent with Prometheus/Grafana MCPs

## 🎯 Next Steps

1. **Update Documentation**: Update main README and guides with AKS-only deployment
2. **Remove Local Scripts**: Archive old `start-postgres-mcp.ps1` (no longer needed)
3. **CI/CD Pipeline**: Add PostgreSQL MCP to automated build pipeline
4. **Monitoring**: Add PostgreSQL MCP metrics to Grafana dashboards
5. **Load Testing**: Test with JMeter under load
6. **Production Hardening**:
   - Move secrets to Azure Key Vault
   - Enable network policies
   - Configure resource limits based on actual usage
   - Set up alerts for pod failures

## 🏆 Success Criteria Met

✅ All three MCP servers running in AKS  
✅ Consistent deployment pattern across all MCPs  
✅ High availability with 2 replicas each  
✅ Health checks configured  
✅ Kubernetes-native management  
✅ Simple port-forward access  
✅ Production-ready architecture  

**PostgreSQL MCP is now fully integrated into the AKS cluster!** 🎉
