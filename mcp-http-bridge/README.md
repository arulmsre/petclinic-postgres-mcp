# MCP HTTP Bridge

HTTP bridge that wraps stdio-based MCP servers, enabling them to be deployed as HTTP services in cloud environments.

## Features

- ✅ Wraps any stdio MCP server with HTTP interface
- ✅ Automatic process management and restart on failure
- ✅ JSON-RPC over HTTP
- ✅ Health check endpoint
- ✅ CORS support
- ✅ Request timeout handling
- ✅ Graceful shutdown

## Usage

### Environment Variables

- `PORT` - HTTP server port (default: 3000)
- `MCP_COMMAND` - Command to run MCP server (default: 'node')
- `MCP_ARGS` - Comma-separated args for MCP server (default: 'dist/index.js')
- `MCP_CWD` - Working directory for MCP server (default: current directory)

### Local Development

```bash
npm install
npm run build

# Run with Prometheus MCP server
export MCP_COMMAND=node
export MCP_ARGS=dist/index.js
export MCP_CWD=../prometheus-mcp-server
npm start
```

### Docker

```bash
# Build
docker build -t mcp-http-bridge .

# Run with Prometheus MCP
docker run -p 3000:3000 \
  -e MCP_COMMAND=node \
  -e MCP_ARGS=dist/index.js \
  -e MCP_CWD=/mcp-server \
  -v $(pwd)/../prometheus-mcp-server:/mcp-server \
  mcp-http-bridge
```

## API Endpoints

### GET /
Server information

### GET /health
Health check
```json
{
  "status": "healthy",
  "mcpServerRunning": true,
  "uptime": 123.45,
  "pendingRequests": 0
}
```

### POST /initialize
Initialize MCP connection
```json
{
  "clientInfo": {
    "name": "my-client",
    "version": "1.0.0"
  },
  "capabilities": {}
}
```

### GET /tools
List available tools

### POST /tools/call
Call a tool
```json
{
  "name": "toolName",
  "arguments": {}
}
```

### GET /resources
List available resources

### POST /resources/read
Read a resource
```json
{
  "uri": "resource://path"
}
```

### GET /prompts
List available prompts

### POST /prompts/get
Get a prompt
```json
{
  "name": "promptName",
  "arguments": {}
}
```

### POST /rpc
Generic JSON-RPC endpoint
```json
{
  "method": "anyMethod",
  "params": {}
}
```

## Integration with MCP Servers

This bridge can wrap any stdio-based MCP server. For the Prometheus and Grafana MCP servers:

### Prometheus MCP
```bash
MCP_COMMAND=node \
MCP_ARGS=dist/index.js \
MCP_CWD=../prometheus-mcp-server \
PROMETHEUS_URL=http://prometheus:9090 \
npm start
```

### Grafana MCP
```bash
MCP_COMMAND=node \
MCP_ARGS=dist/index.js \
MCP_CWD=../grafana-mcp-server \
GRAFANA_URL=http://grafana:80 \
GRAFANA_USER=admin \
GRAFANA_PASSWORD=admin \
npm start
```

## Deployment

See parent directory documentation for deploying to:
- Azure Container Apps
- Azure Kubernetes Service
- Azure App Service

The bridge enables these stdio MCP servers to run as HTTP services in cloud environments.
