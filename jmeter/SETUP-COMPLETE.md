# ✅ JMeter Load Testing Setup Complete!

## What's Been Created

### JMeter Test Plan
- **[jmeter/petclinic-load-test.jmx](petclinic-load-test.jmx)** - Comprehensive load test plan
  - Tests all microservices (Customers, Vets, Visits, API Gateway)
  - Configurable parameters (threads, duration, host, port)
  - 40% Customers, 30% Vets, 20% Visits, 10% API Gateway
  - Response assertions and multiple listeners
  - Realistic think time (1-3 seconds)
  - Random data generation

### Scripts
- **[jmeter/run-load-test.ps1](run-load-test.ps1)** - Automated test runner
  - Predefined scenarios: light, medium, heavy, stress, custom
  - Auto-detects port-forward or LoadBalancer
  - Generates HTML reports automatically
  - Quick summary of results

### Documentation
- **[jmeter/JMETER-LOAD-TESTING-GUIDE.md](JMETER-LOAD-TESTING-GUIDE.md)** - Complete guide
  - Installation instructions
  - Detailed parameter explanations
  - Monitoring guide
  - Troubleshooting section
  - CI/CD examples

- **[jmeter/README.md](README.md)** - Quick start guide
  - 5-minute quick start
  - Common examples
  - Troubleshooting tips

## 🚀 Quick Start

### 1. Install JMeter (if not installed)

**Windows:**
```powershell
# Download and extract JMeter 5.6.3
$version = "5.6.3"
Invoke-WebRequest "https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-$version.zip" -OutFile "$env:TEMP\jmeter.zip"
Expand-Archive "$env:TEMP\jmeter.zip" -DestinationPath "C:\jmeter"

# Add to PATH
$env:PATH += ";C:\jmeter\apache-jmeter-$version\bin"
```

**Verify:**
```powershell
jmeter --version
```

### 2. Run Your First Test

**Option A: Local (Port-Forward)**
```powershell
# Terminal 1: Start port-forward
kubectl port-forward -n petclinic service/api-gateway 8080:8080

# Terminal 2: Run test
cd jmeter
.\run-load-test.ps1 -Scenario light -Target local
```

**Option B: External (LoadBalancer)**
```powershell
cd jmeter
.\run-load-test.ps1 -Scenario light -Target external
```

### 3. View Results

The script automatically:
- ✅ Generates HTML report
- ✅ Opens report in browser
- ✅ Shows quick summary

## 📊 Test Scenarios

| Command | Users | Duration | Description |
|---------|-------|----------|-------------|
| `.\run-load-test.ps1 -Scenario light -Target local` | 5 | 3 min | Quick smoke test |
| `.\run-load-test.ps1 -Scenario medium -Target external` | 20 | 10 min | Typical load |
| `.\run-load-test.ps1 -Scenario heavy -Target external` | 100 | 30 min | Peak load |
| `.\run-load-test.ps1 -Scenario stress -Target external` | 200 | 60 min | Stress test |
| `.\run-load-test.ps1 -Scenario custom -Threads 50 -Duration 600` | 50 | 10 min | Custom test |

## 📈 Monitoring During Tests

### Prometheus (Metrics)
```powershell
kubectl port-forward -n petclinic service/prometheus 9090:9090
# Open: http://localhost:9090
```

### Grafana (Dashboards)
```powershell
# Already accessible at: http://20.81.80.200
# Login: admin/admin
```

### Kubernetes (Resources)
```powershell
# Watch pod metrics
kubectl top pods -n petclinic --watch

# Watch logs
kubectl logs -f -n petclinic -l app=api-gateway

# Watch events
kubectl get events -n petclinic --watch
```

## 🎯 What Gets Tested

### API Endpoints

**GET Requests (70% of traffic)**

**Customers Service (30%)**
- `GET /api/customer/owners` - List all owners
- `GET /api/customer/owners/{ownerId}` - Get owner details

**Vets Service (20%)**
- `GET /api/vet/vets` - List all veterinarians

**Visits Service (15%)**
- `GET /api/visit/owners/*/pets/{petId}/visits` - Get pet visits

**API Gateway (5%)**
- `GET /api/gateway/owners/{ownerId}` - Combined owner + visits data

**POST Requests (30% of traffic)**

**Create Owner (15%)**
- `POST /api/customer/owners` - Create new owner with random data
  - Generates random names, addresses, phone numbers
  - Returns created owner ID

**Add Pet (10%)**
- `POST /api/customer/owners/{ownerId}/pets` - Add pet to owner
  - Generates random pet names, birth dates
  - Uses random pet types (1-6)
  - Returns created pet ID

**Create Visit (5%)**
- `POST /api/visit/owners/*/pets/{petId}/visits` - Schedule pet visit
  - Uses current date
  - Generates random visit descriptions
  - Returns created visit ID

### Test Features

- ✅ **Random Data**: Auto-generated owner IDs, pet IDs, pet types, names, addresses
- ✅ **Think Time**: 1-3 second delays between requests
- ✅ **Response Validation**: Asserts HTTP 200 (GET) and 201 (POST) status codes
- ✅ **JSON Extraction**: Captures created IDs from POST responses
- ✅ **Realistic Distribution**: 70% read (GET), 30% write (POST) operations
- ✅ **Data Chaining**: Uses extracted IDs in subsequent requests
- ✅ **Configurable**: Override any parameter via command line

## 📁 Results Structure

```
jmeter/results/
├── light-local-20260121-143025.jtl          # Raw results
├── light-local-20260121-143025-html/         # HTML dashboard
│   ├── index.html                            # Main report
│   ├── content/                              # Charts and graphs
│   └── sbadmin2-1.0.7/                       # UI assets
├── medium-external-20260121-150030.jtl
└── medium-external-20260121-150030-html/
```

## 🔍 Understanding Results

### HTML Report Sections

1. **Dashboard** - Overview with key metrics
2. **Summary** - Aggregated statistics per request
3. **Response Times** - Distribution and percentiles
4. **Throughput** - Requests per second over time
5. **Errors** - Failed requests and error messages

### Key Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| **Throughput** | Requests/sec | Stable, > 50 req/s |
| **Average Response Time** | Mean latency | < 200ms |
| **Median** | 50th percentile | < 150ms |
| **90th Percentile** | 90% under this time | < 300ms |
| **95th Percentile** | 95% under this time | < 500ms |
| **99th Percentile** | 99% under this time | < 1000ms |
| **Error Rate** | % of failed requests | < 1% |
| **Min/Max** | Best/worst response time | Monitor max |

## 🛠️ Customization

### Edit Test Plan

```powershell
# Open in JMeter GUI
jmeter

# File → Open → jmeter\petclinic-load-test.jmx
# Modify as needed
# File → Save
```

### Custom Scenarios

Add your own scenarios to `run-load-test.ps1`:

```powershell
$scenarios = @{
    mytest = @{
        threads = 30
        ramptime = 90
        duration = 900
        description = "My Custom Test - 30 users, 15 minutes"
    }
}
```

Run with:
```powershell
.\run-load-test.ps1 -Scenario mytest -Target external
```

## 📚 Documentation Links

- **[Complete Guide](JMETER-LOAD-TESTING-GUIDE.md)** - Full documentation
- **[Quick Start](README.md)** - Fast setup
- **[Test Plan](petclinic-load-test.jmx)** - JMeter configuration

## 🎓 Best Practices

1. **Start Small** - Begin with light scenario, increase gradually
2. **Monitor** - Watch Prometheus, Grafana, and Kubernetes metrics
3. **Baseline** - Record baseline metrics before changes
4. **Warm-up** - Run short test first to warm JVM
5. **Clean Data** - Reset database between major test runs
6. **Document** - Save results and notes for comparison
7. **Iterate** - Test → Analyze → Optimize → Repeat

## 🔗 Integration with MCP

You can now use GitHub Copilot MCP to analyze load test results!

```
@workspace Show me the current load on the application during the JMeter test

@workspace What's the memory usage trend for services during high load?

@workspace Are there any errors or bottlenecks visible in Prometheus during the load test?

@workspace Show me the Grafana dashboard for JVM metrics during peak load
```

## ✅ What's Ready

- ✅ JMeter test plan with all endpoints
- ✅ Automated test runner script
- ✅ Pre-configured scenarios (light/medium/heavy/stress)
- ✅ HTML report generation
- ✅ Monitoring integration guides
- ✅ Comprehensive documentation
- ✅ Troubleshooting guides
- ✅ CI/CD examples

## 🚀 Next Steps

1. **Run baseline test:**
   ```powershell
   cd jmeter
   .\run-load-test.ps1 -Scenario light -Target local
   ```

2. **Review results in HTML report**

3. **Check Prometheus metrics during test**

4. **Review Grafana dashboards**

5. **Document baseline metrics**

6. **Run progressively heavier loads**

7. **Identify and fix bottlenecks**

8. **Re-test to validate improvements**

---

**Everything is ready! Start with a light test and scale up as needed. 🚀**
