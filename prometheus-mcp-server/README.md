# Prometheus MCP Server for Spring Petclinic

This is a Model Context Protocol (MCP) server that enables AI assistants to query and analyze Prometheus metrics from your Spring Petclinic application.

## Features

- 🔍 Execute PromQL queries
- 📊 Query time-series data ranges
- 📋 List available metrics
- 🎯 Check scrape targets status
- ⚙️ View Prometheus configuration
- 🏥 Health checks for Petclinic services
- 📈 Comprehensive metrics summary

## Installation

```powershell
# Navigate to the MCP server directory
cd prometheus-mcp-server

# Install dependencies
npm install

# Build the TypeScript code
npm run build
```

## Configuration

### Local Development (Port Forwarding)

```powershell
# Start port forwarding to Prometheus in AKS
kubectl port-forward -n petclinic service/prometheus 9090:9090

# Set environment variable (PowerShell)
$env:PROMETHEUS_URL = "http://localhost:9090"

# Or in your MCP settings
{
  "mcpServers": {
    "prometheus": {
      "command": "node",
      "args": ["d:\\SRE Activity\\CapG_Assets\\Working\\cloud-sre-demo-applications\\spring-petclinic-microservices\\prometheus-mcp-server\\dist\\index.js"],
      "env": {
        "PROMETHEUS_URL": "http://localhost:9090"
      }
    }
  }
}
```

### Production (Direct Connection)

If Prometheus has a public endpoint:

```json
{
  "mcpServers": {
    "prometheus": {
      "command": "node",
      "args": ["d:\\SRE Activity\\CapG_Assets\\Working\\cloud-sre-demo-applications\\spring-petclinic-microservices\\prometheus-mcp-server\\dist\\index.js"],
      "env": {
        "PROMETHEUS_URL": "http://prometheus.example.com:9090"
      }
    }
  }
}
```

## VS Code Integration

### Option 1: Add to Claude Desktop Settings

1. Open Claude Desktop settings file:
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`
   - Mac: `~/Library/Application Support/Claude/claude_desktop_config.json`

2. Add the MCP server configuration:

```json
{
  "mcpServers": {
    "prometheus": {
      "command": "node",
      "args": [
        "d:\\SRE Activity\\CapG_Assets\\Working\\cloud-sre-demo-applications\\spring-petclinic-microservices\\prometheus-mcp-server\\dist\\index.js"
      ],
      "env": {
        "PROMETHEUS_URL": "http://localhost:9090"
      }
    }
  }
}
```

3. Restart Claude Desktop

### Option 2: GitHub Copilot Extension Integration

Add to your `.vscode/settings.json`:

```json
{
  "github.copilot.advanced": {
    "mcp.servers": {
      "prometheus": {
        "command": "node",
        "args": [
          "${workspaceFolder}/prometheus-mcp-server/dist/index.js"
        ],
        "env": {
          "PROMETHEUS_URL": "http://localhost:9090"
        }
      }
    }
  }
}
```

## Available Tools

### 1. prometheus_query
Execute instant PromQL queries.

**Example queries:**
```promql
# Check service health
up{job="petclinic-services"}

# JVM memory usage
jvm_memory_used_bytes{app="customers-service"}

# HTTP request rate (5-minute average)
rate(http_server_requests_seconds_count{app="api-gateway"}[5m])

# 95th percentile response time
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))

# CPU usage
process_cpu_usage{app=~".*-service"}
```

### 2. prometheus_query_range
Query time-series data over a time range.

**Example:**
```json
{
  "query": "rate(http_server_requests_seconds_count[5m])",
  "start": "2026-01-21T10:00:00Z",
  "end": "2026-01-21T11:00:00Z",
  "step": "1m"
}
```

### 3. prometheus_list_metrics
List all available metrics being collected.

### 4. prometheus_get_targets
View all Prometheus scrape targets and their status.

### 5. prometheus_get_config
Retrieve the current Prometheus configuration.

### 6. prometheus_petclinic_health
Quick health check for all Petclinic microservices.

### 7. prometheus_petclinic_metrics
Comprehensive metrics summary (memory, CPU, requests, errors).

**Optional filter by service:**
```json
{
  "service": "customers-service"
}
```

## Usage Examples

### In Claude Desktop

Once configured, you can ask Claude:

- "What's the memory usage of the customers-service?"
- "Show me the HTTP request rate for the last hour"
- "Are all Petclinic services healthy?"
- "What's the error rate for api-gateway?"
- "List all available Prometheus metrics"

### Testing with MCP Inspector

```powershell
# Install MCP Inspector
npm install -g @modelcontextprotocol/inspector

# Test the server
npm run inspector
```

This will open a web interface where you can test all tools.

## Common PromQL Queries for Spring Petclinic

### Service Health
```promql
# All services up/down status
up{job="petclinic-services"}

# Count of running services
count(up{job="petclinic-services"} == 1)
```

### Memory Metrics
```promql
# Heap memory usage
jvm_memory_used_bytes{area="heap"}

# Non-heap memory usage
jvm_memory_used_bytes{area="nonheap"}

# Memory usage by service
jvm_memory_used_bytes{app="customers-service",area="heap"}
```

### HTTP Metrics
```promql
# Total requests per second (5-min average)
sum(rate(http_server_requests_seconds_count[5m])) by (app)

# Requests by status code
sum(rate(http_server_requests_seconds_count[5m])) by (status)

# Error rate (5xx responses)
rate(http_server_requests_seconds_count{status=~"5.."}[5m])

# Average response time
rate(http_server_requests_seconds_sum[5m]) / rate(http_server_requests_seconds_count[5m])

# 95th percentile latency
histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket[5m])) by (le, app))
```

### Database Metrics
```promql
# Database connection pool size
hikaricp_connections_active{app=~".*-service"}

# Database query rate
rate(spring_data_repository_invocations_seconds_count[5m])
```

### JVM Metrics
```promql
# CPU usage
process_cpu_usage{app=~".*-service"}

# Thread count
jvm_threads_live{app=~".*-service"}

# Garbage collection time
rate(jvm_gc_pause_seconds_sum[5m])
```

### Business Metrics (if instrumented)
```promql
# Custom metrics examples (if you add them)
petclinic_owners_total
petclinic_visits_total
petclinic_pets_by_type
```

## Troubleshooting

### Connection Refused

**Issue:** Cannot connect to Prometheus

**Solution:**
```powershell
# Ensure port forwarding is active
kubectl port-forward -n petclinic service/prometheus 9090:9090

# Test connection
curl http://localhost:9090/api/v1/query?query=up

# Or in PowerShell
Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=up"
```

### No Data Returned

**Issue:** Queries return empty results

**Solution:**
1. Check if services are exposing metrics:
```powershell
kubectl exec -n petclinic deployment/customers-service -- curl localhost:8081/actuator/prometheus
```

2. Verify Prometheus is scraping:
```promql
# Check scrape status
up{job="petclinic-services"}

# Check last scrape time
prometheus_target_interval_length_seconds
```

3. Check service labels match scrape config:
```powershell
kubectl get pods -n petclinic --show-labels
```

### MCP Server Not Responding

**Issue:** Tools not available in Claude/Copilot

**Solution:**
1. Rebuild the server:
```powershell
cd prometheus-mcp-server
npm run build
```

2. Test manually:
```powershell
node dist/index.js
```

3. Check logs in Claude Desktop or VS Code

## Integration with Grafana

While this MCP server queries Prometheus directly, you can still use Grafana for visualization:

```powershell
# Access Grafana
kubectl port-forward -n petclinic service/grafana 3001:80

# Open in browser
Start-Process http://localhost:3001
```

Login: `admin/admin`

## Next Steps

### Add Custom Metrics to Spring Boot Services

Edit your Spring Boot services to expose custom business metrics:

```java
// Add to your service classes
@Component
public class MetricsService {
    private final MeterRegistry meterRegistry;
    
    @Autowired
    public MetricsService(MeterRegistry meterRegistry) {
        this.meterRegistry = meterRegistry;
    }
    
    public void recordOwnerCreated() {
        meterRegistry.counter("petclinic.owners.created").increment();
    }
    
    public void recordVisit(String petType) {
        meterRegistry.counter("petclinic.visits", "pet_type", petType).increment();
    }
}
```

Then query with:
```promql
rate(petclinic_owners_created_total[5m])
sum by (pet_type) (petclinic_visits_total)
```

### Setup Alerting

Create alerts in Prometheus for critical conditions:

```yaml
# Add to prometheus-config ConfigMap
groups:
  - name: petclinic
    rules:
      - alert: ServiceDown
        expr: up{job="petclinic-services"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.app }} is down"
      
      - alert: HighErrorRate
        expr: rate(http_server_requests_seconds_count{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate on {{ $labels.app }}"
```

## Resources

- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Spring Boot Actuator Metrics](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html#actuator.metrics)

## License

MIT
