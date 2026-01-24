# Quick Start - JMeter Load Testing

## 🚀 Quick Test (5 minutes)

### Prerequisites
- JMeter installed ([See installation guide](JMETER-LOAD-TESTING-GUIDE.md#1-install-apache-jmeter))
- Petclinic deployed on AKS
- kubectl configured

### Option 1: Local Testing (Port-Forward)

**Step 1: Start Port-Forward** (in separate terminal)
```powershell
kubectl port-forward -n petclinic service/api-gateway 8080:8080
```

**Step 2: Run Light Load Test**
```powershell
.\run-load-test.ps1 -Scenario light -Target local
```

### Option 2: External Testing (LoadBalancer)

```powershell
.\run-load-test.ps1 -Scenario light -Target external
```

## 📊 Test Scenarios

| Scenario | Users | Duration | Use Case |
|----------|-------|----------|----------|
| `light` | 5 | 3 min | Quick smoke test |
| `medium` | 20 | 10 min | Typical load |
| `heavy` | 100 | 30 min | Peak load |
| `stress` | 200 | 60 min | Find breaking point |
| `custom` | Custom | Custom | Your parameters |

## 💡 Examples

### Light Load Test (Local)
```powershell
.\run-load-test.ps1 -Scenario light -Target local
```

### Medium Load Test (External)
```powershell
.\run-load-test.ps1 -Scenario medium -Target external
```

### Custom Load Test
```powershell
.\run-load-test.ps1 -Scenario custom -Threads 50 -Duration 600 -Target external
```

### Test with Custom Host
```powershell
.\run-load-test.ps1 -Scenario medium -CustomHost "petclinic.example.com" -CustomPort 80
```

## 🎯 What Gets Tested

The test plan includes **both read (GET) and write (POST) operations** across all microservices:

### GET Requests (70% of traffic)
- **Browse Owners (30%)**: GET /api/customer/owners, GET /api/customer/owners/{ownerId}
- **View Vets (20%)**: GET /api/vet/vets
- **View Visits (15%)**: GET /api/visit/owners/*/pets/{petId}/visits
- **API Gateway (5%)**: GET /api/gateway/owners/{ownerId}

### POST Requests (30% of traffic)
- **Create Owner (15%)**: POST /api/customer/owners - Random names, addresses, phone numbers
- **Add Pet (10%)**: POST /api/customer/owners/{ownerId}/pets - Random pet names, birth dates, types
- **Create Visit (5%)**: POST /api/visit/owners/*/pets/{petId}/visits - Random visit descriptions

### Test Features
- ✅ Random data generation for realistic testing
- ✅ Response validation (200 for GET, 201 for POST)
- ✅ JSON extraction from POST responses
- ✅ 1-3 second think time between requests

## 📈 Viewing Results

After the test completes:

1. **HTML Report** opens automatically (or in `jmeter\results\<timestamp>-html\index.html`)
2. **JTL File** in `jmeter\results\<timestamp>.jtl`

## 🔍 Monitoring During Test

### Prometheus Metrics
```powershell
kubectl port-forward -n petclinic service/prometheus 9090:9090
# Open: http://localhost:9090
```

### Grafana Dashboards
```powershell
# Already accessible at:
# http://20.81.80.200
# Login: admin/admin
```

### Pod Resource Usage
```powershell
kubectl top pods -n petclinic --watch
```

### Pod Logs
```powershell
# API Gateway logs
kubectl logs -f -n petclinic -l app=api-gateway

# Customers Service logs
kubectl logs -f -n petclinic -l app=customers-service
```

## 🎯 Key Metrics to Watch

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| Avg Response Time | < 200ms | 200-500ms | > 500ms |
| 95th Percentile | < 500ms | 500-1000ms | > 1000ms |
| Error Rate | 0% | 0-1% | > 1% |
| Throughput | Stable | Fluctuating | Dropping |

## 🛠️ Troubleshooting

### "JMeter not found"
```powershell
# Install JMeter (see JMETER-LOAD-TESTING-GUIDE.md)
# Or add to PATH
$env:PATH += ";C:\jmeter\apache-jmeter-5.6.3\bin"
```

### "Port 8080 not accessible"
```powershell
# Start port-forwarding
kubectl port-forward -n petclinic service/api-gateway 8080:8080
```

### "Failed to get external IP"
```powershell
# Patch service to LoadBalancer
kubectl patch svc api-gateway -n petclinic -p '{"spec":{"type":"LoadBalancer"}}'

# Wait for IP assignment
kubectl get svc api-gateway -n petclinic -w
```

### High Error Rates
```powershell
# Check pod health
kubectl get pods -n petclinic

# Check pod logs
kubectl logs -n petclinic -l app=api-gateway --tail=100

# Check service endpoints
kubectl get endpoints -n petclinic
```

## 📚 Full Documentation

For detailed information, see:
- **[Complete Guide](JMETER-LOAD-TESTING-GUIDE.md)** - Comprehensive documentation
- **[Test Plan](petclinic-load-test.jmx)** - JMeter test configuration

## 🎓 Tips

1. **Start small** - Begin with light scenario, then increase load
2. **Monitor infrastructure** - Watch CPU, memory, network during tests  
3. **Warm-up** - Run a short test first to warm up JVM and caches
4. **Clean results** - Clear old results: `Remove-Item jmeter\results\* -Recurse`
5. **Baseline** - Establish baseline metrics before optimization

## 🔗 Related

- [Prometheus MCP Setup](../PROMETHEUS-MCP-SETUP.md)
- [Grafana MCP Setup](../GRAFANA-MCP-SETUP.md)
- [Deployment Guide](../COMPLETE-DEPLOYMENT-GUIDE.md)

---

**Happy Load Testing! 🚀**
