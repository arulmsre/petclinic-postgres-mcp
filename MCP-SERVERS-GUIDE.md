# MCP Servers Guide - PetClinic Monitoring

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Your MCP Servers                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Prometheus MCP (stdio) ──► HTTP Bridge ──► Port 8090   │
│     - Queries Prometheus at prometheus.petclinic:9090      │
│     - Tools: prometheus_query, prometheus_list_metrics     │
│                                                             │
│  2. Grafana MCP (stdio) ──► HTTP Bridge ──► Port 8091      │
│     - Connects to Grafana at http://20.241.201.24          │
│     - Tools: grafana_search_dashboards, grafana_get_panel  │
│                                                             │
│  3. PostgreSQL MCP (stdio) ──► HTTP Bridge ──► Port 8092   │
│     - Connects to PostgreSQL at localhost:5433             │
│     - Tools: query, list_tables, describe_table            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Two Communication Modes

### 1. stdio (Standard Input/Output)
- Native MCP protocol
- Used by Claude Desktop
- Direct process communication via JSON-RPC

### 2. HTTP (via HTTP Bridge)
- Wraps stdio MCP in HTTP endpoints
- Used for testing, web apps, Python clients
- Accessible on ports: 8090, 8091, 8092

---

## How to Run the MCP Servers

### Option 1: All-in-One Command (Recommended)

```powershell
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward svc/postgres -n petclinic 5433:5432"; Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n petclinic service/prometheus-mcp-service 8090:80"; Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n petclinic service/grafana-mcp-service 8091:80"; Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$env:PORT='8092'; `$env:MCP_COMMAND='node'; `$env:MCP_ARGS='../postgres-mcp-server/dist/index.js'; `$env:MCP_CWD='../postgres-mcp-server'; `$env:PG_HOST='localhost'; `$env:PG_PORT='5433'; `$env:PG_DATABASE='petclinic'; `$env:PG_USER='petclinic'; `$env:PG_PASSWORD='petclinic'; `$env:PG_SSL='false'; cd mcp-http-bridge; node dist/index.js"
```

This opens 4 PowerShell windows:
1. PostgreSQL port-forward (5433:5432)
2. Prometheus MCP HTTP bridge (port 8090)
3. Grafana MCP HTTP bridge (port 8091)
4. PostgreSQL MCP HTTP bridge (port 8092)

### Option 2: Manual Step-by-Step

**Window 1: PostgreSQL Port-Forward**
```powershell
kubectl port-forward svc/postgres -n petclinic 5433:5432
```

**Window 2: Prometheus MCP**
```powershell
kubectl port-forward -n petclinic service/prometheus-mcp-service 8090:80
```

**Window 3: Grafana MCP**
```powershell
kubectl port-forward -n petclinic service/grafana-mcp-service 8091:80
```

**Window 4: PostgreSQL MCP**
```powershell
cd mcp-http-bridge
$env:PORT='8092'
$env:MCP_COMMAND='node'
$env:MCP_ARGS='../postgres-mcp-server/dist/index.js'
$env:MCP_CWD='../postgres-mcp-server'
$env:PG_HOST='localhost'
$env:PG_PORT='5433'
$env:PG_DATABASE='petclinic'
$env:PG_USER='petclinic'
$env:PG_PASSWORD='petclinic'
$env:PG_SSL='false'
node dist/index.js
```

---

## How to Get Details from MCP Servers

### Method 1: PowerShell HTTP Requests

#### List Available Tools
```powershell
# Prometheus tools
Invoke-RestMethod -Uri "http://localhost:8090/tools" | ConvertTo-Json -Depth 10

# Grafana tools
Invoke-RestMethod -Uri "http://localhost:8091/tools" | ConvertTo-Json -Depth 10

# PostgreSQL tools
Invoke-RestMethod -Uri "http://localhost:8092/tools" | ConvertTo-Json -Depth 10
```

#### Query Prometheus
```powershell
$body = @{
    name = "prometheus_query"
    arguments = @{
        query = "up{job='petclinic-services'}"
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8090/message" -Method POST -Body $body -ContentType "application/json"
```

#### Search Grafana Dashboards
```powershell
$body = @{
    name = "grafana_search_dashboards"
    arguments = @{
        query = "petclinic"
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8091/message" -Method POST -Body $body -ContentType "application/json"
```

#### Query PostgreSQL
```powershell
$body = @{
    name = "query"
    arguments = @{
        sql = "SELECT * FROM vets LIMIT 5"
    }
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8092/message" -Method POST -Body $body -ContentType "application/json"
```

### Method 2: Python Client

**Simple Client:**
```python
import requests
import json

def call_mcp(base_url, tool_name, arguments=None):
    """Call an MCP tool via HTTP bridge"""
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": arguments or {}
        }
    }
    response = requests.post(f"{base_url}/message", json=payload)
    return response.json()

# Example: Get service health from Prometheus
result = call_mcp("http://localhost:8090", "prometheus_query", {
    "query": "up"
})
print(result['result']['content'][0]['text'])

# Example: Get Grafana dashboards
result = call_mcp("http://localhost:8091", "grafana_search_dashboards", {
    "query": "petclinic"
})
print(result['result']['content'][0]['text'])

# Example: Query PostgreSQL
result = call_mcp("http://localhost:8092", "query", {
    "sql": "SELECT COUNT(*) FROM owners"
})
print(result['result']['content'][0]['text'])
```

**Advanced Python Client:**
```python
import requests
import json
from datetime import datetime

class MCPClient:
    def __init__(self, base_url):
        self.base_url = base_url
        self.message_id = 0
    
    def list_tools(self):
        """List available tools from the MCP server"""
        response = requests.get(f"{self.base_url}/tools")
        return response.json()
    
    def call_tool(self, tool_name, arguments=None):
        """Call a tool on the MCP server"""
        self.message_id += 1
        payload = {
            "jsonrpc": "2.0",
            "id": self.message_id,
            "method": "tools/call",
            "params": {
                "name": tool_name,
                "arguments": arguments or {}
            }
        }
        
        response = requests.post(
            f"{self.base_url}/message",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        return response.json()

# Create clients for all three servers
prometheus = MCPClient("http://localhost:8090")
grafana = MCPClient("http://localhost:8091")
postgres = MCPClient("http://localhost:8092")

# Use them
print("=== Prometheus MCP ===")
prom_tools = prometheus.list_tools()
print(f"Available tools: {len(prom_tools['tools'])} tools")

result = prometheus.call_tool("prometheus_query", {"query": "up"})
print(f"Query result:\n{result['result']['content'][0]['text'][:200]}...\n")

print("=== Grafana MCP ===")
result = grafana.call_tool("grafana_search_dashboards", {"query": "petclinic"})
print(f"Dashboards:\n{result['result']['content'][0]['text']}\n")

print("=== PostgreSQL MCP ===")
result = postgres.call_tool("query", {"sql": "SELECT COUNT(*) as total_vets FROM vets"})
print(f"Query result:\n{result['result']['content'][0]['text']}\n")
```

**PetClinic Monitor (Complete Example):**
```python
# petclinic_monitor.py
import requests
import json
from datetime import datetime

class PetClinicMonitor:
    def __init__(self):
        self.prometheus = self._create_client("http://localhost:8090")
        self.grafana = self._create_client("http://localhost:8091")
        self.postgres = self._create_client("http://localhost:8092")
    
    def _create_client(self, base_url):
        return {"url": base_url, "msg_id": 0}
    
    def _call(self, client, tool, args=None):
        client["msg_id"] += 1
        payload = {
            "jsonrpc": "2.0",
            "id": client["msg_id"],
            "method": "tools/call",
            "params": {"name": tool, "arguments": args or {}}
        }
        resp = requests.post(f"{client['url']}/message", json=payload)
        return resp.json()
    
    def get_service_health(self):
        """Get health status of all PetClinic services"""
        result = self._call(self.prometheus, "prometheus_query", {
            "query": "up{job='petclinic-services'}"
        })
        return result['result']['content'][0]['text']
    
    def get_database_stats(self):
        """Get database statistics"""
        queries = [
            ("Owners", "SELECT COUNT(*) FROM owners"),
            ("Pets", "SELECT COUNT(*) FROM pets"),
            ("Vets", "SELECT COUNT(*) FROM vets"),
            ("Visits", "SELECT COUNT(*) FROM visits")
        ]
        
        stats = {}
        for name, sql in queries:
            result = self._call(self.postgres, "query", {"sql": sql})
            stats[name] = result['result']['content'][0]['text']
        
        return stats
    
    def get_dashboards(self):
        """Get Grafana dashboards"""
        result = self._call(self.grafana, "grafana_search_dashboards", {
            "query": "petclinic"
        })
        return result['result']['content'][0]['text']
    
    def full_report(self):
        """Generate a full monitoring report"""
        print(f"\n{'='*60}")
        print(f"PetClinic Monitoring Report - {datetime.now()}")
        print(f"{'='*60}\n")
        
        print("📊 Service Health:")
        print(self.get_service_health())
        
        print("\n📈 Database Statistics:")
        for key, value in self.get_database_stats().items():
            print(f"  {key}: {value}")
        
        print("\n📋 Grafana Dashboards:")
        print(self.get_dashboards())

# Usage
monitor = PetClinicMonitor()
monitor.full_report()
```

### Method 3: Test Script (Easiest)

```powershell
# Run the included test script
.\test-mcp-http.ps1
```

### Method 4: Claude Desktop (stdio mode)

**Configuration File:** `$env:APPDATA\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "prometheus": {
      "command": "node",
      "args": ["D:/SRE Activity/CapG_Assets/Working/cloud-sre-demo-applications/spring-petclinic-microservices/prometheus-mcp-server/dist/index.js"],
      "env": {
        "PROMETHEUS_URL": "http://localhost:9090"
      }
    },
    "grafana": {
      "command": "node",
      "args": ["D:/SRE Activity/CapG_Assets/Working/cloud-sre-demo-applications/spring-petclinic-microservices/grafana-mcp-server/dist/index.js"],
      "env": {
        "GRAFANA_URL": "http://20.241.201.24",
        "GRAFANA_USERNAME": "admin",
        "GRAFANA_PASSWORD": "admin"
      }
    },
    "postgres": {
      "command": "node",
      "args": ["D:/SRE Activity/CapG_Assets/Working/cloud-sre-demo-applications/spring-petclinic-microservices/postgres-mcp-server/dist/index.js"],
      "env": {
        "PG_HOST": "localhost",
        "PG_PORT": "5433",
        "PG_DATABASE": "petclinic",
        "PG_USER": "petclinic",
        "PG_PASSWORD": "petclinic",
        "PG_SSL": "false"
      }
    }
  }
}
```

**Required Port-Forwards for Claude Desktop:**
```powershell
# Prometheus (for Prometheus MCP to query)
kubectl port-forward -n petclinic service/prometheus 9090:9090

# PostgreSQL (for PostgreSQL MCP to connect)
kubectl port-forward svc/postgres -n petclinic 5433:5432
```

**After configuration:**
1. Save the config file
2. Start the required port-forwards
3. Restart Claude Desktop
4. Ask questions like:
   - "Query Prometheus for the up metric"
   - "Show me all Grafana dashboards"
   - "How many pets are in the database?"

---

## Available Tools by Server

### Prometheus MCP (7 tools)

| Tool | Description | Example Arguments |
|------|-------------|-------------------|
| `prometheus_query` | Query metrics at a single point in time | `{"query": "up"}` |
| `prometheus_query_range` | Query metrics over a time range | `{"query": "up", "start": "2026-01-22T00:00:00Z", "end": "2026-01-22T23:59:59Z", "step": "1m"}` |
| `prometheus_list_metrics` | List all available metrics | `{}` |
| `prometheus_get_targets` | Get scrape targets and their status | `{}` |
| `prometheus_get_config` | Get Prometheus configuration | `{}` |
| `prometheus_petclinic_health` | Check health of PetClinic services | `{}` |
| `prometheus_petclinic_metrics` | Get PetClinic-specific metrics | `{}` |

**Example Queries:**
```powershell
# Get all service status
prometheus_query: {"query": "up{job='petclinic-services'}"}

# Get CPU usage
prometheus_query: {"query": "process_cpu_seconds_total"}

# Get memory usage
prometheus_query: {"query": "jvm_memory_used_bytes"}

# Get HTTP request rate
prometheus_query: {"query": "rate(http_server_requests_seconds_count[5m])"}
```

### Grafana MCP (Multiple tools)

| Tool | Description | Example Arguments |
|------|-------------|-------------------|
| `grafana_search_dashboards` | Search for dashboards by name | `{"query": "petclinic"}` |
| `grafana_get_dashboard` | Get dashboard details by UID | `{"uid": "afaz31pwtzu2oa"}` |
| `grafana_list_datasources` | List all configured data sources | `{}` |
| `grafana_get_panel_data` | Get data from a specific panel | `{"dashboardUid": "afaz31pwtzu2oa", "panelId": 1}` |

**Example Queries:**
```powershell
# Find PetClinic dashboard
grafana_search_dashboards: {"query": "petclinic"}

# Get dashboard by UID (from search results)
grafana_get_dashboard: {"uid": "afaz31pwtzu2oa"}

# List all data sources
grafana_list_datasources: {}
```

**Dashboard UID:** `afaz31pwtzu2oa`
**Dashboard URL:** http://20.241.201.24/d/afaz31pwtzu2oa/petclinic

### PostgreSQL MCP (Multiple tools)

| Tool | Description | Example Arguments |
|------|-------------|-------------------|
| `query` | Execute SQL SELECT query | `{"sql": "SELECT * FROM vets"}` |
| `list_tables` | List all tables in the database | `{}` |
| `describe_table` | Get table schema/structure | `{"table": "vets"}` |
| `list_databases` | List all databases | `{}` |

**Example Queries:**
```powershell
# Get all vets
query: {"sql": "SELECT * FROM vets"}

# Count owners
query: {"sql": "SELECT COUNT(*) FROM owners"}

# Get pets with owners
query: {"sql": "SELECT p.name, o.first_name, o.last_name FROM pets p JOIN owners o ON p.owner_id = o.id"}

# List all tables
list_tables: {}

# Describe vets table
describe_table: {"table": "vets"}
```

**Database Schema:**
- `owners` - Pet owners
- `pets` - Pets belonging to owners
- `vets` - Veterinarians
- `visits` - Vet visits
- `specialties` - Vet specialties
- `vet_specialties` - Mapping of vets to specialties
- `types` - Pet types

---

## Health Check

```powershell
# Check if all MCP servers are running
foreach ($port in @(8090, 8091, 8092)) {
    try {
        $health = Invoke-RestMethod "http://localhost:$port/health"
        Write-Host "Port ${port}: $($health.status) (uptime: $($health.uptime)s)" -ForegroundColor Green
    } catch {
        Write-Host "Port ${port}: Not running" -ForegroundColor Red
    }
}
```

**Expected Output:**
```
Port 8090: healthy (uptime: 1234.56s)
Port 8091: healthy (uptime: 1234.56s)
Port 8092: healthy (uptime: 1234.56s)
```

---

## Troubleshooting

### MCP Servers Not Responding

1. **Check if port-forwards are running:**
   ```powershell
   Get-Process | Where-Object {$_.ProcessName -eq "kubectl"} | Select-Object Id, ProcessName, StartTime
   ```

2. **Restart all servers:**
   - Close all PowerShell windows
   - Run the all-in-one command again

### PostgreSQL Connection Failed

1. **Check PostgreSQL port-forward:**
   ```powershell
   kubectl port-forward svc/postgres -n petclinic 5433:5432
   ```

2. **Test connection:**
   ```powershell
   Test-NetConnection -ComputerName localhost -Port 5433
   ```

### Prometheus Not Returning Data

1. **Verify Prometheus is accessible:**
   ```powershell
   Invoke-RestMethod "http://prometheus.petclinic.svc.cluster.local:9090/api/v1/status/config"
   ```

2. **Check if Prometheus MCP HTTP bridge is running:**
   ```powershell
   Invoke-RestMethod "http://localhost:8090/health"
   ```

### Grafana Authentication Failed

1. **Verify credentials:**
   - Username: `admin`
   - Password: `admin`

2. **Test Grafana access:**
   ```powershell
   Invoke-RestMethod "http://20.241.201.24/api/health"
   ```

---

## Common Use Cases

### 1. Monitor Service Health
```python
result = call_mcp("http://localhost:8090", "prometheus_query", {
    "query": "up{job='petclinic-services'}"
})
print(result['result']['content'][0]['text'])
```

### 2. Get Database Statistics
```python
stats = [
    "SELECT COUNT(*) as owners FROM owners",
    "SELECT COUNT(*) as pets FROM pets",
    "SELECT COUNT(*) as vets FROM vets",
    "SELECT COUNT(*) as visits FROM visits"
]

for sql in stats:
    result = call_mcp("http://localhost:8092", "query", {"sql": sql})
    print(result['result']['content'][0]['text'])
```

### 3. Find and Open Dashboard
```python
# Search for dashboard
result = call_mcp("http://localhost:8091", "grafana_search_dashboards", {
    "query": "petclinic"
})
print(result['result']['content'][0]['text'])

# Dashboard UID: afaz31pwtzu2oa
# Open: http://20.241.201.24/d/afaz31pwtzu2oa/petclinic
```

### 4. Check Application Performance
```python
queries = [
    "rate(http_server_requests_seconds_count[5m])",  # Request rate
    "jvm_memory_used_bytes",                          # Memory usage
    "process_cpu_seconds_total"                       # CPU usage
]

for query in queries:
    result = call_mcp("http://localhost:8090", "prometheus_query", {"query": query})
    print(f"{query}:\n{result['result']['content'][0]['text']}\n")
```

---

## Summary

**MCP Servers Endpoints:**
- Prometheus MCP: http://localhost:8090
- Grafana MCP: http://localhost:8091
- PostgreSQL MCP: http://localhost:8092

**Quick Start:**
```powershell
# Start all servers
Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward svc/postgres -n petclinic 5433:5432"; Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n petclinic service/prometheus-mcp-service 8090:80"; Start-Process powershell -ArgumentList "-NoExit", "-Command", "kubectl port-forward -n petclinic service/grafana-mcp-service 8091:80"; Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$env:PORT='8092'; `$env:MCP_COMMAND='node'; `$env:MCP_ARGS='../postgres-mcp-server/dist/index.js'; `$env:MCP_CWD='../postgres-mcp-server'; `$env:PG_HOST='localhost'; `$env:PG_PORT='5433'; `$env:PG_DATABASE='petclinic'; `$env:PG_USER='petclinic'; `$env:PG_PASSWORD='petclinic'; `$env:PG_SSL='false'; cd mcp-http-bridge; node dist/index.js"

# Test
.\test-mcp-http.ps1

# Health check
foreach ($port in @(8090, 8091, 8092)) { Invoke-RestMethod "http://localhost:$port/health" }
```

**Keep PowerShell windows open** to maintain MCP server connections!
