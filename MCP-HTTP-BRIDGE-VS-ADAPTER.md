# MCP HTTP Bridge vs MCP HTTP Adapter

Understanding the difference between `mcp-http-bridge` and `mcp-http-adapter` and when to use each.

---

## Table of Contents
- [Overview](#overview)
- [mcp-http-bridge](#mcp-http-bridge)
- [mcp-http-adapter](#mcp-http-adapter)
- [Key Differences](#key-differences)
- [When to Use Each](#when-to-use-each)
- [How They Work Together](#how-they-work-together)
- [Code Examples](#code-examples)
- [Current Setup](#current-setup)

---

## Overview

Both components serve as middleware between HTTP clients and MCP servers, but they have different purposes:

- **mcp-http-bridge**: Generic HTTP wrapper for any stdio-based MCP server
- **mcp-http-adapter**: Service-specific adapters with custom business logic

---

## mcp-http-bridge

### **Purpose**
Wraps stdio-based MCP servers and exposes them as HTTP endpoints.

### **What It Does**

1. **Spawns an MCP server process** via stdio (standard input/output)
2. **Translates HTTP requests** to JSON-RPC messages
3. **Forwards messages** to the MCP server via stdin
4. **Receives responses** from the MCP server via stdout
5. **Returns HTTP responses** to clients

### **Architecture**

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ HTTP Client │────►│ HTTP Bridge │────►│ stdio MCP   │────►│ Prometheus  │
│  (Python)   │ REST│ (Translator)│JSON │  Server     │ HTTP│  Grafana    │
│  (PS)       │     │             │ RPC │             │     │  PostgreSQL │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

### **Data Flow**

**Step 1: Client sends HTTP POST**
```http
POST http://localhost:8092/message
Content-Type: application/json

{
  "name": "query",
  "arguments": {"sql": "SELECT * FROM vets"}
}
```

**Step 2: Bridge converts to JSON-RPC (sent via stdin)**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "query",
    "arguments": {"sql": "SELECT * FROM vets"}
  }
}
```

**Step 3: MCP server processes and responds via stdout**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [{
      "type": "text",
      "text": "id | first_name | last_name\n1  | James      | Carter\n..."
    }]
  }
}
```

**Step 4: Bridge converts back to HTTP response**
```json
{
  "result": {
    "content": [{
      "type": "text",
      "text": "id | first_name | last_name\n1  | James      | Carter\n..."
    }]
  }
}
```

### **Configuration (Environment Variables)**

| Variable | Description | Example |
|----------|-------------|---------|
| `PORT` | HTTP server port | `8092` |
| `MCP_COMMAND` | Command to run MCP server | `node` |
| `MCP_ARGS` | Arguments for MCP server | `dist/index.js` |
| `MCP_CWD` | Working directory for MCP server | `../postgres-mcp-server` |

### **Use Cases**

✅ Testing MCP servers via HTTP/REST  
✅ Python/PowerShell clients accessing MCP  
✅ Web applications querying MCP servers  
✅ Running MCP locally for development  
✅ Quick prototyping without writing adapters  
✅ Generic access from any HTTP client (curl, Postman, etc.)

### **Example Usage**

```powershell
# Start PostgreSQL MCP with HTTP bridge
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
node dist/index.js
```

**Expected Output:**
```
MCP HTTP Bridge listening on port 8092
Starting MCP server: node ../postgres-mcp-server/dist/index.js
Working directory: ../postgres-mcp-server
```

### **Endpoints**

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/tools` | GET | List available tools |
| `/message` | POST | Execute MCP tool |

---

## mcp-http-adapter

### **Purpose**
Provides **service-specific adapters** that wrap MCP server logic with custom business logic.

### **What It Does**

1. **Adds custom logic** around MCP server functionality
2. **Transforms data** before/after MCP calls
3. **Implements service-specific features** (caching, filtering, aggregation)
4. **Provides convenience methods** for common operations
5. **Adds authentication, rate limiting, logging**

### **Architecture**

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌──────────┐
│ HTTP Client │────►│HTTP Adapter │────►│Custom Logic │────►│ MCP Server  │────►│   Data   │
│  (Browser)  │ REST│(grafana-    │     │Transform    │JSON │(stdio)      │ HTTP│  Source  │
│  (App)      │     │ adapter.js) │     │Cache        │ RPC │             │     │          │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘     └──────────┘
```

### **Files in mcp-http-adapter/**

```
mcp-http-adapter/
├── grafana-adapter.js      # Grafana-specific adapter with custom logic
├── prometheus-adapter.js   # Prometheus-specific adapter
└── postgres-adapter.js     # PostgreSQL-specific adapter (optional)
```

### **Features Added by Adapters**

#### **1. Caching**
```javascript
// grafana-adapter.js
const cache = new Map();

async function getCachedDashboard(uid) {
  if (cache.has(uid)) {
    console.log('Cache hit for dashboard:', uid);
    return cache.get(uid);
  }
  
  const dashboard = await mcpServer.getDashboard(uid);
  cache.set(uid, dashboard, { ttl: 300 }); // 5 min cache
  return dashboard;
}
```

#### **2. Data Transformation**
```javascript
// grafana-adapter.js
async function getDashboardSummary(uid) {
  const dashboard = await mcpServer.getDashboard(uid);
  
  // Transform to simplified format
  return {
    title: dashboard.title,
    panelCount: dashboard.panels.length,
    tags: dashboard.tags,
    lastUpdated: dashboard.meta.updated,
    url: `${GRAFANA_URL}/d/${uid}`
  };
}
```

#### **3. Data Aggregation**
```javascript
// prometheus-adapter.js
async function getAllServiceMetrics() {
  const services = ['customers-service', 'visits-service', 'vets-service', 'api-gateway'];
  const metrics = [];
  
  for (const service of services) {
    const memory = await mcpServer.query(`jvm_memory_used_bytes{app="${service}"}`);
    const cpu = await mcpServer.query(`process_cpu_usage{app="${service}"}`);
    const requests = await mcpServer.query(`http_server_requests_seconds_count{app="${service}"}`);
    
    metrics.push({
      service,
      memory: parseMetric(memory),
      cpu: parseMetric(cpu),
      requestRate: calculateRate(requests)
    });
  }
  
  return metrics;
}
```

#### **4. Custom Endpoints**
```javascript
// prometheus-adapter.js
app.get('/api/health/summary', async (req, res) => {
  const summary = await getServiceHealthSummary();
  res.json(summary);
});

app.get('/api/metrics/performance/:service', async (req, res) => {
  const metrics = await getServicePerformance(req.params.service);
  res.json(metrics);
});

app.get('/api/alerts/active', async (req, res) => {
  const alerts = await getActiveAlerts();
  res.json(alerts);
});
```

#### **5. Rate Limiting**
```javascript
// grafana-adapter.js
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use('/api/', limiter);
```

#### **6. Authentication**
```javascript
// grafana-adapter.js
function authenticate(req, res, next) {
  const apiKey = req.headers['x-api-key'];
  
  if (!apiKey || !isValidApiKey(apiKey)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  next();
}

app.use('/api/', authenticate);
```

### **Use Cases**

✅ Adding business logic on top of MCP  
✅ Caching frequently accessed data  
✅ Data transformation/aggregation  
✅ Custom endpoints for specific workflows  
✅ Rate limiting, authentication, logging  
✅ Combining multiple MCP calls into one endpoint  
✅ Building a custom API layer

---

## Key Differences

| Feature | mcp-http-bridge | mcp-http-adapter |
|---------|----------------|------------------|
| **Purpose** | Generic HTTP wrapper | Service-specific business logic |
| **Complexity** | Simple pass-through | Custom logic + transformations |
| **Reusability** | Works with any MCP server | Specific to one service |
| **Configuration** | Environment variables only | Can have custom config files |
| **Data Flow** | Direct translation | Transformation + enhancement |
| **Performance** | Fast (no processing) | Slower (custom logic) |
| **Examples** | Same for all services | grafana-adapter.js, prometheus-adapter.js |
| **Code Size** | ~200 lines | Can be 1000+ lines |
| **Customization** | None | Highly customizable |
| **Maintenance** | Easy | Requires updates for changes |

---

## When to Use Each

### Use **mcp-http-bridge** when:

✅ You need simple HTTP access to any MCP server  
✅ Testing/debugging MCP servers  
✅ No custom business logic needed  
✅ Quick prototyping  
✅ Generic clients (Python scripts, PowerShell, curl)  
✅ Low latency required  
✅ Want to keep it simple  

**Example Scenarios:**
- Quick local testing of MCP servers
- Python script querying Prometheus
- PowerShell automation accessing PostgreSQL
- Development/debugging
- Minimal overhead required

### Use **mcp-http-adapter** when:

✅ You need service-specific features  
✅ Caching, rate limiting, or data transformation required  
✅ Building a custom API on top of MCP  
✅ Complex workflows involving multiple MCP calls  
✅ Need to add authentication/authorization  
✅ Want custom endpoints tailored to your use case  
✅ Combining data from multiple sources  

**Example Scenarios:**
- Production API with caching and rate limiting
- Custom dashboard aggregating multiple metrics
- Public API requiring authentication
- Complex queries combining Prometheus + PostgreSQL
- Business intelligence reports

---

## How They Work Together

### **Current Setup (AKS Deployment)**

**Prometheus MCP Pod:**
```
┌─────────────────────────────────────────────────────────┐
│ Kubernetes Pod: prometheus-mcp                          │
│                                                         │
│  ┌──────────────────┐         ┌──────────────────┐    │
│  │  HTTP Bridge     │ stdio   │ Prometheus MCP   │    │
│  │  (port 3000)     │────────►│  Server          │    │
│  │  Generic wrapper │         │  (node dist/...)  │    │
│  └──────────────────┘         └──────────────────┘    │
│         │                              │               │
└─────────┼──────────────────────────────┼───────────────┘
          │                              │
          │ HTTP                         │ HTTP
          ▼                              ▼
   kubectl port-forward           http://prometheus:9090
   localhost:8090
```

**Grafana MCP Pod:**
```
┌─────────────────────────────────────────────────────────┐
│ Kubernetes Pod: grafana-mcp                             │
│                                                         │
│  ┌──────────────────┐         ┌──────────────────┐    │
│  │  HTTP Bridge     │ stdio   │ Grafana MCP      │    │
│  │  (port 3000)     │────────►│  Server          │    │
│  │  Generic wrapper │         │  (node dist/...)  │    │
│  └──────────────────┘         └──────────────────┘    │
│         │                              │               │
└─────────┼──────────────────────────────┼───────────────┘
          │                              │
          │ HTTP                         │ HTTP
          ▼                              ▼
   kubectl port-forward           http://20.241.201.24
   localhost:8091                 (Grafana)
```

**PostgreSQL MCP (Local):**
```
┌─────────────────────────────────────────────────────────┐
│ Local Process: PostgreSQL MCP HTTP Bridge              │
│                                                         │
│  ┌──────────────────┐         ┌──────────────────┐    │
│  │  HTTP Bridge     │ stdio   │ PostgreSQL MCP   │    │
│  │  (port 8092)     │────────►│  Server          │    │
│  │  Generic wrapper │         │  (node dist/...)  │    │
│  └──────────────────┘         └──────────────────┘    │
│         │                              │               │
└─────────┼──────────────────────────────┼───────────────┘
          │                              │
          │ HTTP                         │ PostgreSQL
          ▼                              ▼
   http://localhost:8092          localhost:5433
```

### **Enhanced Setup with Adapters**

**With Custom Prometheus Adapter:**
```
┌─────────────────────────────────────────────────────────────────┐
│ Kubernetes Pod: prometheus-mcp-enhanced                         │
│                                                                 │
│  ┌──────────────────┐    ┌──────────────────┐    ┌──────────┐ │
│  │ Prometheus       │    │ HTTP Bridge      │    │Prometheus│ │
│  │ Adapter          │────►│                  │────►│   MCP    │ │
│  │ + Caching        │calls│ stdio wrapper    │stdio│  Server  │ │
│  │ + Aggregation    │    │                  │    │          │ │
│  │ + Custom API     │    │                  │    │          │ │
│  └──────────────────┘    └──────────────────┘    └──────────┘ │
│         │                                                       │
└─────────┼───────────────────────────────────────────────────────┘
          │
          ▼
   Custom Endpoints:
   /api/metrics/summary
   /api/services/health
   /api/performance/:service
   /api/alerts/active
```

---

## Code Examples

### **HTTP Bridge (Generic)**

```javascript
// mcp-http-bridge/src/index.ts
import express from 'express';
import { spawn } from 'child_process';

const app = express();
const PORT = process.env.PORT || 3000;
const MCP_COMMAND = process.env.MCP_COMMAND || 'node';
const MCP_ARGS = process.env.MCP_ARGS?.split(' ') || ['dist/index.js'];

// Spawn MCP server process
const mcpProcess = spawn(MCP_COMMAND, MCP_ARGS, {
  stdio: ['pipe', 'pipe', 'pipe'],
  cwd: process.env.MCP_CWD
});

let messageId = 0;
const pendingResponses = new Map();

// Handle stdout from MCP server
mcpProcess.stdout.on('data', (data) => {
  const lines = data.toString().split('\n').filter(Boolean);
  
  lines.forEach(line => {
    try {
      const response = JSON.parse(line);
      const callback = pendingResponses.get(response.id);
      if (callback) {
        callback(response);
        pendingResponses.delete(response.id);
      }
    } catch (err) {
      console.error('Failed to parse MCP response:', err);
    }
  });
});

// Health endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    mcpServerRunning: !mcpProcess.killed,
    uptime: process.uptime()
  });
});

// List tools endpoint
app.get('/tools', async (req, res) => {
  const id = messageId++;
  
  const request = {
    jsonrpc: '2.0',
    id,
    method: 'tools/list',
    params: {}
  };
  
  // Send to MCP server via stdin
  mcpProcess.stdin.write(JSON.stringify(request) + '\n');
  
  // Wait for response via stdout
  const response = await new Promise((resolve) => {
    pendingResponses.set(id, resolve);
  });
  
  res.json(response.result);
});

// Execute tool endpoint
app.post('/message', async (req, res) => {
  const { name, arguments: args } = req.body;
  const id = messageId++;
  
  const request = {
    jsonrpc: '2.0',
    id,
    method: 'tools/call',
    params: { name, arguments: args }
  };
  
  // Send to MCP server via stdin
  mcpProcess.stdin.write(JSON.stringify(request) + '\n');
  
  // Wait for response via stdout
  const response = await new Promise((resolve, reject) => {
    pendingResponses.set(id, resolve);
    setTimeout(() => reject(new Error('Timeout')), 30000);
  });
  
  res.json(response);
});

app.listen(PORT, () => {
  console.log(`MCP HTTP Bridge listening on port ${PORT}`);
});
```

**Characteristics:**
- ✅ Simple, generic code
- ✅ Works with any MCP server
- ✅ No business logic
- ✅ Direct pass-through
- ✅ Easy to understand and maintain

### **HTTP Adapter (Custom)**

```javascript
// mcp-http-adapter/prometheus-adapter.js
import express from 'express';
import NodeCache from 'node-cache';
import { callMCP } from './mcp-client.js';

const app = express();
const cache = new NodeCache({ stdTTL: 300 }); // 5 min cache

// Middleware: Logging
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Middleware: Rate limiting
const rateLimit = new Map();
app.use((req, res, next) => {
  const ip = req.ip;
  const requests = rateLimit.get(ip) || [];
  const now = Date.now();
  
  // Remove old requests (older than 1 minute)
  const recentRequests = requests.filter(time => now - time < 60000);
  
  if (recentRequests.length >= 100) {
    return res.status(429).json({ error: 'Too many requests' });
  }
  
  recentRequests.push(now);
  rateLimit.set(ip, recentRequests);
  next();
});

// Custom endpoint: Service health summary
app.get('/api/health/summary', async (req, res) => {
  const cacheKey = 'health-summary';
  const cached = cache.get(cacheKey);
  
  if (cached) {
    return res.json({ ...cached, cached: true });
  }
  
  // Call MCP server
  const result = await callMCP('prometheus_query', {
    query: 'up{job="petclinic-services"}'
  });
  
  // Parse Prometheus response
  const services = parsePrometheusResponse(result);
  
  // Transform to summary
  const summary = {
    timestamp: new Date().toISOString(),
    total: services.length,
    healthy: services.filter(s => s.value === 1).length,
    unhealthy: services.filter(s => s.value === 0).length,
    services: services.map(s => ({
      name: s.app,
      status: s.value === 1 ? 'UP' : 'DOWN',
      instance: s.instance,
      lastScrape: s.timestamp
    }))
  };
  
  cache.set(cacheKey, summary);
  res.json(summary);
});

// Custom endpoint: Performance metrics
app.get('/api/metrics/performance/:service', async (req, res) => {
  const { service } = req.params;
  const cacheKey = `performance-${service}`;
  const cached = cache.get(cacheKey);
  
  if (cached) {
    return res.json({ ...cached, cached: true });
  }
  
  // Multiple MCP calls
  const [memory, cpu, requests, errors] = await Promise.all([
    callMCP('prometheus_query', {
      query: `jvm_memory_used_bytes{app="${service}",area="heap"}`
    }),
    callMCP('prometheus_query', {
      query: `process_cpu_usage{app="${service}"}`
    }),
    callMCP('prometheus_query', {
      query: `rate(http_server_requests_seconds_count{app="${service}"}[5m])`
    }),
    callMCP('prometheus_query', {
      query: `rate(http_server_requests_seconds_count{app="${service}",status=~"5.."}[5m])`
    })
  ]);
  
  // Aggregate and transform
  const metrics = {
    timestamp: new Date().toISOString(),
    service,
    memory: {
      bytes: parseMetricValue(memory),
      formatted: formatBytes(parseMetricValue(memory))
    },
    cpu: {
      percent: parseMetricValue(cpu) * 100,
      formatted: `${(parseMetricValue(cpu) * 100).toFixed(2)}%`
    },
    requestRate: {
      perSecond: parseMetricValue(requests),
      formatted: `${parseMetricValue(requests).toFixed(2)} req/s`
    },
    errorRate: {
      perSecond: parseMetricValue(errors),
      percent: (parseMetricValue(errors) / parseMetricValue(requests)) * 100,
      formatted: `${((parseMetricValue(errors) / parseMetricValue(requests)) * 100).toFixed(2)}%`
    }
  };
  
  cache.set(cacheKey, metrics);
  res.json(metrics);
});

// Custom endpoint: Active alerts
app.get('/api/alerts/active', async (req, res) => {
  const result = await callMCP('prometheus_query', {
    query: 'ALERTS{alertstate="firing"}'
  });
  
  const alerts = parsePrometheusResponse(result).map(alert => ({
    name: alert.alertname,
    severity: alert.severity,
    service: alert.app,
    summary: alert.summary,
    description: alert.description,
    since: alert.timestamp
  }));
  
  res.json({
    timestamp: new Date().toISOString(),
    count: alerts.length,
    alerts
  });
});

// Custom endpoint: Time-range queries
app.get('/api/metrics/history/:metric', async (req, res) => {
  const { metric } = req.params;
  const { service, hours = 1 } = req.query;
  
  const end = new Date();
  const start = new Date(end.getTime() - hours * 60 * 60 * 1000);
  
  const result = await callMCP('prometheus_query_range', {
    query: `${metric}{app="${service}"}`,
    start: start.toISOString(),
    end: end.toISOString(),
    step: '1m'
  });
  
  const timeseries = parseTimeSeriesResponse(result);
  
  res.json({
    metric,
    service,
    timeRange: {
      start: start.toISOString(),
      end: end.toISOString()
    },
    dataPoints: timeseries.length,
    data: timeseries
  });
});

// Utility functions
function parsePrometheusResponse(result) {
  // Custom parsing logic
  const text = result.content[0].text;
  const lines = text.split('\n').filter(Boolean);
  
  return lines.map(line => {
    const match = line.match(/{(.+)} => (.+) @ (.+)/);
    if (!match) return null;
    
    const labels = {};
    match[1].split(', ').forEach(label => {
      const [key, value] = label.split('=');
      labels[key] = value.replace(/"/g, '');
    });
    
    return {
      ...labels,
      value: parseFloat(match[2]),
      timestamp: match[3]
    };
  }).filter(Boolean);
}

function formatBytes(bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let size = bytes;
  let unitIndex = 0;
  
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  
  return `${size.toFixed(2)} ${units[unitIndex]}`;
}

app.listen(8093, () => {
  console.log('Prometheus Adapter listening on port 8093');
});
```

**Characteristics:**
- ✅ Service-specific logic
- ✅ Caching for performance
- ✅ Custom endpoints
- ✅ Data transformation
- ✅ Rate limiting
- ✅ Multiple MCP calls aggregated
- ✅ Business-friendly responses

---

## Current Setup

### **What You're Using Now**

You're currently using **mcp-http-bridge** for all three MCP servers:

1. **Prometheus MCP** (AKS pod on port 8090)
   - Generic HTTP bridge wrapping Prometheus MCP server
   - No custom logic
   - Direct pass-through to Prometheus

2. **Grafana MCP** (AKS pod on port 8091)
   - Generic HTTP bridge wrapping Grafana MCP server
   - No custom logic
   - Direct pass-through to Grafana

3. **PostgreSQL MCP** (Local on port 8092)
   - Generic HTTP bridge wrapping PostgreSQL MCP server
   - No custom logic
   - Direct pass-through to PostgreSQL

### **Why This Works**

✅ Simple and reliable  
✅ Easy to deploy and maintain  
✅ Low latency  
✅ Sufficient for basic querying  
✅ Works with any HTTP client  
✅ No additional complexity

### **When You Might Need Adapters**

Consider adding **mcp-http-adapter** if you need:

- ❓ Caching to reduce load on Prometheus/Grafana
- ❓ Custom API endpoints for specific workflows
- ❓ Data aggregation from multiple sources
- ❓ Rate limiting for public APIs
- ❓ Authentication/authorization
- ❓ Complex data transformations
- ❓ Business intelligence reports

### **The mcp-http-adapter Directory**

The `mcp-http-adapter/` directory exists in your project but:

- 📁 Contains optional enhanced features
- 📁 For advanced use cases
- 📁 Not required for basic HTTP access
- 📁 Can be used alongside or instead of bridges

**Current deployment uses bridges only** - adapters are there for future enhancements if needed!

---

## Summary

| Aspect | mcp-http-bridge | mcp-http-adapter |
|--------|----------------|------------------|
| **Role** | Generic HTTP wrapper | Custom business logic layer |
| **When to use** | Simple HTTP access, testing, development | Production APIs, caching, complex workflows |
| **Complexity** | Low (~200 lines) | High (1000+ lines) |
| **Performance** | Fast (no overhead) | Slower (processing) |
| **Customization** | None | Extensive |
| **Current status** | ✅ In use (all 3 servers) | 📁 Available but not deployed |

**Bottom line:** mcp-http-bridge is sufficient for most use cases. Add mcp-http-adapter when you need service-specific features, caching, or custom API endpoints.

---

**Last Updated:** January 22, 2026  
**Status:** ✅ Documentation Complete
