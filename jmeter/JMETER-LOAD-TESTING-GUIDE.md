# JMeter Load Testing Guide for Spring Petclinic Microservices

## Overview

This guide provides comprehensive instructions for load testing the Spring Petclinic microservices application using Apache JMeter.

## Prerequisites

### 1. Install Apache JMeter

**Windows:**
```powershell
# Download JMeter
$jmeterVersion = "5.6.3"
$downloadUrl = "https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-$jmeterVersion.zip"
$destination = "$env:USERPROFILE\Downloads\apache-jmeter-$jmeterVersion.zip"

# Download
Invoke-WebRequest -Uri $downloadUrl -OutFile $destination

# Extract
Expand-Archive -Path $destination -DestinationPath "C:\jmeter" -Force

# Add to PATH (run as Administrator)
[Environment]::SetEnvironmentVariable("JMETER_HOME", "C:\jmeter\apache-jmeter-$jmeterVersion", "Machine")
$path = [Environment]::GetEnvironmentVariable("Path", "Machine")
[Environment]::SetEnvironmentVariable("Path", "$path;C:\jmeter\apache-jmeter-$jmeterVersion\bin", "Machine")
```

**Linux/Mac:**
```bash
wget https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-5.6.3.tgz
tar -xzf apache-jmeter-5.6.3.tgz
sudo mv apache-jmeter-5.6.3 /opt/jmeter
export JMETER_HOME=/opt/jmeter
export PATH=$PATH:$JMETER_HOME/bin
```

### 2. Verify Installation

```powershell
jmeter --version
```

Expected output:
```
Apache JMeter 5.6.3
```

## Test Plan Structure

The JMeter test plan ([jmeter/petclinic-load-test.jmx](jmeter/petclinic-load-test.jmx)) includes:

### Test Scenarios

| Scenario | Percentage | Description |
|----------|------------|-------------|
| Browse Owners (GET) | 30% | GET /api/customer/owners and owner details |
| View Vets (GET) | 20% | GET /api/vet/vets |
| View Visits (GET) | 15% | GET /api/visit/owners/*/pets/{petId}/visits |
| Create Owner (POST) | 15% | POST /api/customer/owners with random owner data |
| Add Pet (POST) | 10% | POST /api/customer/owners/{ownerId}/pets with random pet data |
| API Gateway (GET) | 5% | GET /api/gateway/owners/{ownerId} |
| Create Visit (POST) | 5% | POST /api/visit/owners/*/pets/{petId}/visits with visit data |

### Key Features

- **Configurable Parameters**: Host, port, threads, duration via command-line
- **Realistic Think Time**: 1-3 second delays between requests
- **Random Data**: Owner IDs, Pet IDs, Pet Types, names, addresses, phone numbers
- **Response Assertions**: Validates HTTP 200 (GET) and 201 (POST) status codes
- **JSON Data Extraction**: Captures IDs from POST responses for chaining requests
- **Read/Write Mix**: 70% GET requests, 30% POST requests (realistic workload)
- **Multiple Listeners**: Summary, Graph, Results Tree
- **InfluxDB Integration**: Optional metrics export (disabled by default)

## Running Load Tests

### Option 1: Port-Forward (Local Testing)

**Step 1: Start Port Forwarding**
```powershell
kubectl port-forward -n petclinic service/api-gateway 8080:8080
```

**Step 2: Run Test**
```powershell
jmeter -n -t jmeter\petclinic-load-test.jmx `
  -Jhost=localhost `
  -Jport=8080 `
  -Jthreads=10 `
  -Jramptime=60 `
  -Jduration=300 `
  -l results\test-results.jtl `
  -e -o results\html-report
```

### Option 2: LoadBalancer (External Testing)

**Step 1: Get External IP**
```powershell
# Patch service to LoadBalancer type (if not already)
kubectl patch svc api-gateway -n petclinic -p '{"spec":{"type":"LoadBalancer"}}'

# Wait for external IP
kubectl get svc api-gateway -n petclinic -w

# Get IP
$EXTERNAL_IP = kubectl get svc api-gateway -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "External IP: $EXTERNAL_IP"
```

**Step 2: Run Test**
```powershell
jmeter -n -t jmeter\petclinic-load-test.jmx `
  -Jhost=$EXTERNAL_IP `
  -Jport=8080 `
  -Jthreads=20 `
  -Jramptime=120 `
  -Jduration=600 `
  -l results\test-results.jtl `
  -e -o results\html-report
```

### Option 3: Ingress (Production-like Testing)

```powershell
# Use your ingress hostname
$INGRESS_HOST = "petclinic.yourdomain.com"

jmeter -n -t jmeter\petclinic-load-test.jmx `
  -Jhost=$INGRESS_HOST `
  -Jport=80 `
  -Jprotocol=https `
  -Jthreads=50 `
  -Jramptime=300 `
  -Jduration=1800 `
  -l results\test-results.jtl `
  -e -o results\html-report
```

## Test Parameters

### Command-Line Parameters

| Parameter | Default | Description | Example |
|-----------|---------|-------------|---------|
| `-Jhost` | localhost | API Gateway hostname/IP | -Jhost=20.81.80.200 |
| `-Jport` | 8080 | API Gateway port | -Jport=80 |
| `-Jprotocol` | http | Protocol (http/https) | -Jprotocol=https |
| `-Jthreads` | 10 | Number of virtual users | -Jthreads=50 |
| `-Jramptime` | 60 | Ramp-up time (seconds) | -Jramptime=120 |
| `-Jduration` | 300 | Test duration (seconds) | -Jduration=600 |

### Example Scenarios

**Light Load (Development)**
```powershell
jmeter -n -t jmeter\petclinic-load-test.jmx `
  -Jthreads=5 `
  -Jramptime=30 `
  -Jduration=180 `
  -l results\light-load.jtl
```

**Medium Load (Staging)**
```powershell
jmeter -n -t jmeter\petclinic-load-test.jmx `
  -Jthreads=20 `
  -Jramptime=120 `
  -Jduration=600 `
  -l results\medium-load.jtl
```

**Heavy Load (Performance Testing)**
```powershell
jmeter -n -t jmeter\petclinic-load-test.jmx `
  -Jthreads=100 `
  -Jramptime=300 `
  -Jduration=1800 `
  -l results\heavy-load.jtl
```

**Stress Test (Find Breaking Point)**
```powershell
jmeter -n -t jmeter\petclinic-load-test.jmx `
  -Jthreads=200 `
  -Jramptime=600 `
  -Jduration=3600 `
  -l results\stress-test.jtl
```

## Viewing Results

### Generate HTML Report

After test completion, generate an HTML dashboard:

```powershell
# If not generated during test run
jmeter -g results\test-results.jtl -o results\html-report
```

### Open HTML Report

```powershell
# Windows
Start-Process "results\html-report\index.html"

# Linux/Mac
open results/html-report/index.html
```

### JMeter GUI (Post-Test Analysis)

```powershell
# Open JMeter GUI
jmeter

# Load test plan: jmeter/petclinic-load-test.jmx
# Add listener: Aggregate Report
# Browse to results file: results/test-results.jtl
```

## Monitoring During Load Test

### Watch Prometheus Metrics

```powershell
# Port-forward Prometheus
kubectl port-forward -n petclinic service/prometheus 9090:9090

# Open in browser
Start-Process "http://localhost:9090"

# Useful PromQL queries:
# - Request rate: rate(http_server_requests_seconds_count[1m])
# - Memory usage: jvm_memory_used_bytes{area="heap"}
# - Error rate: rate(http_server_requests_seconds_count{status=~"5.."}[1m])
```

### Watch Grafana Dashboards

```powershell
# Grafana is already exposed at public IP
Start-Process "http://20.81.80.200"

# Login: admin / admin
# View JVM metrics, request rates, etc.
```

### Watch Kubernetes Pods

```powershell
# Watch pod CPU/Memory
kubectl top pods -n petclinic --watch

# Watch pod logs
kubectl logs -f -n petclinic -l app=customers-service

# Watch all events
kubectl get events -n petclinic --watch
```

### Real-time Test Progress

```powershell
# In separate terminal while test runs
Get-Content results\test-results.jtl -Wait -Tail 10
```

## Analyzing Results

### Key Metrics to Review

1. **Throughput**: Requests per second
2. **Response Time**: Average, median, 90th, 95th, 99th percentiles
3. **Error Rate**: Percentage of failed requests
4. **Concurrent Users**: Active threads over time

### Success Criteria Example

| Metric | Target | Acceptable |
|--------|--------|------------|
| Throughput | > 100 req/s | > 80 req/s |
| Avg Response Time | < 200ms | < 500ms |
| 95th Percentile | < 500ms | < 1000ms |
| Error Rate | 0% | < 1% |

### Common Issues

**High Response Times**
- Check pod CPU/memory limits
- Review database connection pool settings
- Examine Prometheus for JVM GC pauses

**High Error Rates (5xx)**
- Check pod logs: `kubectl logs -n petclinic -l app=api-gateway`
- Review Kubernetes events
- Check database connectivity

**Pod Restarts**
- Check resource limits: `kubectl describe pod -n petclinic <pod-name>`
- Review OOMKilled events
- Increase memory limits if needed

## Advanced Usage

### Distributed Load Testing

Run JMeter in distributed mode for higher load:

```powershell
# On server machines (run as JMeter server)
jmeter-server

# On client machine
jmeter -n -t jmeter\petclinic-load-test.jmx `
  -R server1,server2,server3 `
  -l results\distributed-test.jtl
```

### Custom Scenarios

Edit the JMX file to add custom scenarios:

1. Open JMeter GUI: `jmeter`
2. File → Open → `jmeter\petclinic-load-test.jmx`
3. Add/modify samplers under thread groups
4. Save and run

### InfluxDB Integration

Enable real-time metrics export to InfluxDB:

**Step 1: Setup InfluxDB**
```powershell
# Deploy InfluxDB to Kubernetes (optional)
kubectl create namespace monitoring
helm install influxdb influxdata/influxdb2 -n monitoring

# Or use existing InfluxDB instance
```

**Step 2: Enable Backend Listener**

Edit `jmeter/petclinic-load-test.jmx`:
```xml
<!-- Change enabled="false" to enabled="true" -->
<BackendListener ... enabled="true">
  <!-- Update influxdbUrl to your instance -->
  <stringProp name="influxdbUrl">http://influxdb:8086/write?db=jmeter</stringProp>
</BackendListener>
```

**Step 3: Run Test**
```powershell
jmeter -n -t jmeter\petclinic-load-test.jmx -l results\test.jtl
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Load Test

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  workflow_dispatch:

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install JMeter
        run: |
          wget https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-5.6.3.tgz
          tar -xzf apache-jmeter-5.6.3.tgz
          echo "JMETER_HOME=$(pwd)/apache-jmeter-5.6.3" >> $GITHUB_ENV
          
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
        
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
          
      - name: Get AKS Credentials
        run: |
          az aks get-credentials --resource-group rg-petclinic-demo --name aks-petclinic
          
      - name: Get API Gateway IP
        id: get-ip
        run: |
          IP=$(kubectl get svc api-gateway -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
          echo "api_gateway_ip=$IP" >> $GITHUB_OUTPUT
          
      - name: Run Load Test
        run: |
          $JMETER_HOME/bin/jmeter -n \
            -t jmeter/petclinic-load-test.jmx \
            -Jhost=${{ steps.get-ip.outputs.api_gateway_ip }} \
            -Jthreads=20 \
            -Jduration=300 \
            -l results/test.jtl \
            -e -o results/html
            
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: jmeter-results
          path: results/
```

## Best Practices

1. **Start Small**: Begin with low thread counts and gradually increase
2. **Monitor Infrastructure**: Watch CPU, memory, network during tests
3. **Realistic Scenarios**: Match production usage patterns
4. **Warm-up Period**: Allow time for JVM warm-up and caching
5. **Clean Data**: Reset database between major test runs if needed
6. **Document Baselines**: Record baseline metrics for comparison
7. **Test Incrementally**: Test individual services before full integration tests

## Troubleshooting

### JMeter Won't Start

```powershell
# Check Java installation
java -version

# Verify JMETER_HOME
echo $env:JMETER_HOME

# Run with debug
jmeter -n -t test.jmx -l results.jtl -j jmeter.log
```

### Connection Refused

```powershell
# Verify service is accessible
curl http://<host>:<port>/api/customer/owners

# Check port-forwarding
kubectl get svc -n petclinic
```

### Out of Memory

```powershell
# Increase JMeter heap size
$env:JVM_ARGS="-Xms2g -Xmx4g"
jmeter -n -t jmeter\petclinic-load-test.jmx ...
```

## Resources

- [JMeter Documentation](https://jmeter.apache.org/usermanual/index.html)
- [Best Practices](https://jmeter.apache.org/usermanual/best-practices.html)
- [JMeter Plugins](https://jmeter-plugins.org/)
- [Load Testing Guide](https://www.blazemeter.com/blog/jmeter-tutorial)

## Next Steps

1. Run baseline test with default parameters
2. Review Prometheus/Grafana metrics during test
3. Analyze HTML report and identify bottlenecks
4. Tune application/infrastructure based on findings
5. Re-test to validate improvements
6. Establish performance benchmarks

---

**Happy Load Testing! 🚀**
