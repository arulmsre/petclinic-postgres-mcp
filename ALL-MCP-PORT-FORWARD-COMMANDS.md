# ✅ All MCP Servers Port-Forward Commands (Updated - All from AKS!)

## 🎉 Status: All 3 MCP Servers Running in AKS!

All MCP servers (Prometheus, Grafana, and PostgreSQL) are now deployed to AKS with 2 replicas each for high availability.

## 📋 Quick Start Commands

### Option 1: Automated Script (Recommended)
```powershell
.\start-all-mcp-aks.ps1
```
This will open 4 PowerShell windows with all necessary port-forwards.

### Option 2: Manual Commands (Open 4 Separate PowerShell Windows)

**Window 1: PostgreSQL Database**
```powershell
kubectl port-forward service/postgres -n petclinic 5433:5432
```

**Window 2: Prometheus MCP** (from AKS)
```powershell
kubectl port-forward service/prometheus-mcp-service -n petclinic 8090:80
```

**Window 3: Grafana MCP** (from AKS)
```powershell
kubectl port-forward service/grafana-mcp-service -n petclinic 8091:80
```

**Window 4: PostgreSQL MCP** (from AKS) ✨ **NEW!**
```powershell
kubectl port-forward service/postgres-mcp-service -n petclinic 8092:80
```

## 🔗 Access URLs

After running the port-forwards, access the MCP servers at:

| Service | URL | Status |
|---------|-----|--------|
| Prometheus MCP | http://localhost:8090 | ✅ AKS (2 replicas) |
| Grafana MCP | http://localhost:8091 | ✅ AKS (2 replicas) |
| PostgreSQL MCP | http://localhost:8092 | ✅ AKS (2 replicas) |
| PostgreSQL DB | localhost:5433 | ✅ AKS |

## 🧪 Health Checks

```powershell
# Check all MCP servers
Invoke-RestMethod http://localhost:8090/health  # Prometheus MCP
Invoke-RestMethod http://localhost:8091/health  # Grafana MCP
Invoke-RestMethod http://localhost:8092/health  # PostgreSQL MCP (NEW!)
```

Expected response from each:
```json
{
  "status": "ok",
  "server": "mcp-http-bridge"
}
```

## 📊 Verify AKS Deployment

```powershell
# Check all MCP pods
kubectl get pods -n petclinic | Select-String "mcp"

# Expected: 6 pods running (2 replicas × 3 MCP servers)
# prometheus-mcp-xxxxx-xxxxx   1/1     Running
# prometheus-mcp-xxxxx-xxxxx   1/1     Running
# grafana-mcp-xxxxx-xxxxx      1/1     Running
# grafana-mcp-xxxxx-xxxxx      1/1     Running
# postgres-mcp-xxxxx-xxxxx     1/1     Running
# postgres-mcp-xxxxx-xxxxx     1/1     Running

# Check MCP services
kubectl get svc -n petclinic | Select-String "mcp"

# Expected: 3 services
# prometheus-mcp-service   NodePort   80:30090/TCP
# grafana-mcp-service      NodePort   80:30091/TCP
# postgres-mcp-service     NodePort   80:30092/TCP
```

## 🧪 Test PostgreSQL MCP

Run the test script:
```powershell
.\test-postgres-mcp-aks.ps1
```

This will verify:
- ✅ Health endpoint
- ✅ Tools listing
- ✅ Table listing
- ✅ Database queries

Or test manually:

### List PostgreSQL Tools
```powershell
$body = @{
    method = "tools/list"
} | ConvertTo-Json

Invoke-RestMethod -Uri http://localhost:8092/message -Method Post -Body $body -ContentType "application/json"
```

### Query Database
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

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────┐
│          Azure Kubernetes Service (AKS)        │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  Namespace: petclinic                    │  │
│  │                                          │  │
│  │  Prometheus MCP (2 replicas)             │  │
│  │  └─> prometheus-mcp-service:80           │  │
│  │       NodePort: 30090                    │  │
│  │                                          │  │
│  │  Grafana MCP (2 replicas)                │  │
│  │  └─> grafana-mcp-service:80              │  │
│  │       NodePort: 30091                    │  │
│  │                                          │  │
│  │  PostgreSQL MCP (2 replicas) ✨ NEW!     │  │
│  │  └─> postgres-mcp-service:80             │  │
│  │       NodePort: 30092                    │  │
│  │                                          │  │
│  │  PostgreSQL Database                     │  │
│  │  └─> postgres:5432                       │  │
│  │                                          │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
                     ↕
            Port-Forward (kubectl)
                     ↕
┌─────────────────────────────────────────────────┐
│           Local Machine (localhost)             │
│                                                 │
│  Prometheus MCP:  http://localhost:8090        │
│  Grafana MCP:     http://localhost:8091        │
│  PostgreSQL MCP:  http://localhost:8092 ✨ NEW!│
│  PostgreSQL DB:   localhost:5433               │
└─────────────────────────────────────────────────┘
```

## 📦 Docker Images in ACR

All MCP server images are stored in Azure Container Registry:

```
petclinicdemo1234.azurecr.io/
├── prometheus-mcp-http:latest
├── grafana-mcp-http:latest
└── postgres-mcp-http:latest ✨ NEW!
```

## 🔐 Kubernetes Resources

### Deployments (All with 2 replicas)
- `prometheus-mcp` → Deployment
- `grafana-mcp` → Deployment
- `postgres-mcp` → Deployment ✨ NEW!

### Services (All NodePort type)
- `prometheus-mcp-service` → Port 80 (NodePort 30090)
- `grafana-mcp-service` → Port 80 (NodePort 30091)
- `postgres-mcp-service` → Port 80 (NodePort 30092) ✨ NEW!

### Secrets
- `grafana-mcp-secrets` → Grafana credentials
- `postgres-mcp-secrets` → PostgreSQL credentials ✨ NEW!

## 📝 What Changed

### Before
- ❌ Prometheus MCP: AKS
- ❌ Grafana MCP: AKS
- ❌ PostgreSQL MCP: **Local Node.js process**

**Issues:**
- Inconsistent deployment
- Manual process management
- No high availability for PostgreSQL MCP

### After ✅
- ✅ Prometheus MCP: AKS (2 replicas)
- ✅ Grafana MCP: AKS (2 replicas)
- ✅ PostgreSQL MCP: **AKS (2 replicas)**

**Benefits:**
- 🎯 Consistent deployment pattern
- 🔄 High availability (6 total MCP pods)
- 📈 Kubernetes-native scaling
- 🛡️ Health checks and auto-restart
- 🚀 Simplified startup (just port-forwards)

## 🚀 Deployment Files

All MCP servers are defined in:
```
k8s/mcp-servers.yaml
```

This file contains:
- Namespace definition
- 3 Deployments (Prometheus, Grafana, PostgreSQL MCPs)
- 3 Services (NodePort type)
- 2 Secrets (Grafana and PostgreSQL credentials)

To redeploy or update:
```powershell
kubectl apply -f k8s/mcp-servers.yaml
```

## 📚 Additional Documentation

- **Full Deployment Guide**: [POSTGRES-MCP-AKS-DEPLOYMENT.md](POSTGRES-MCP-AKS-DEPLOYMENT.md)
- **Deployment Validation**: [MCP-DEPLOYMENT-VALIDATION-GUIDE.md](MCP-DEPLOYMENT-VALIDATION-GUIDE.md)
- **Usage Guide**: [MCP-SERVERS-GUIDE.md](MCP-SERVERS-GUIDE.md)
- **HTTP Bridge vs Adapter**: [MCP-HTTP-BRIDGE-VS-ADAPTER.md](MCP-HTTP-BRIDGE-VS-ADAPTER.md)

## 🎯 Next Steps

1. **Start Port-Forwards**: Run `.\start-all-mcp-aks.ps1`
2. **Verify Health**: Check all endpoints with `Invoke-RestMethod`
3. **Test PostgreSQL MCP**: Run `.\test-postgres-mcp-aks.ps1`
4. **Use in Applications**: All MCP servers available on localhost ports

## 💡 Tips

- **Stop Port-Forwards**: Press `Ctrl+C` in each terminal window
- **View Logs**: `kubectl logs -n petclinic -l app=postgres-mcp`
- **Scale Replicas**: `kubectl scale deployment/postgres-mcp --replicas=3 -n petclinic`
- **Update Image**: Edit `k8s/mcp-servers.yaml` and `kubectl apply`

---

✅ **All 3 MCP servers are now running in AKS with high availability!**

**Total Resources:**
- 6 MCP pods (2 replicas × 3 servers)
- 3 NodePort services
- 2 Kubernetes secrets
- All images in ACR
