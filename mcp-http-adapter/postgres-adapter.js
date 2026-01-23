#!/usr/bin/env node
/**
 * PostgreSQL MCP HTTP-to-stdio Adapter
 * 
 * This adapter bridges HTTP MCP servers to stdio for Claude Desktop compatibility.
 * It listens on stdin for JSON-RPC requests and forwards them to the HTTP MCP server.
 */

const http = require('http');
const readline = require('readline');

const MCP_HTTP_URL = 'http://localhost:8092';
const REQUEST_TIMEOUT = 30000; // 30 seconds

// Create readline interface for stdio
// Note: No output specified to avoid polluting stdout (used for JSON-RPC)
const rl = readline.createInterface({
  input: process.stdin,
  terminal: false
});

// Cache for tools list
let toolsCache = null;

// Log to stderr (won't interfere with JSON-RPC on stdout)
function log(message) {
  console.error(`[PostgreSQL Adapter] ${new Date().toISOString()} - ${message}`);
}

// Make HTTP request to MCP server
function makeHttpRequest(endpoint, data) {
  return new Promise((resolve, reject) => {
    const url = new URL(endpoint);
    const options = {
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: REQUEST_TIMEOUT
    };

    const req = http.request(options, (res) => {
      let body = '';
      
      res.on('data', (chunk) => {
        body += chunk;
      });
      
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          resolve(parsed);
        } catch (error) {
          reject(new Error(`Failed to parse response: ${error.message}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(new Error(`HTTP request failed: ${error.message}`));
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    req.write(JSON.stringify(data));
    req.end();
  });
}

// Fetch tools list from HTTP endpoint
async function fetchTools() {
  try {
    const url = new URL(`${MCP_HTTP_URL}/tools`);
    const options = {
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname,
      method: 'GET',
      timeout: 5000
    };

    return await new Promise((resolve, reject) => {
      const req = http.request(options, (res) => {
        let body = '';
        res.on('data', (chunk) => { body += chunk; });
        res.on('end', () => {
          try {
            const data = JSON.parse(body);
            // Handle different response formats:
            // - Array: [tool1, tool2, ...]
            // - Object with tools: {tools: [...]}
            // - JSON-RPC wrapped: {result: {tools: [...]}}
            let tools = [];
            if (Array.isArray(data)) {
              tools = data;
            } else if (data.result && data.result.tools) {
              tools = data.result.tools;
            } else if (data.tools) {
              tools = data.tools;
            }
            log(`Fetched ${tools.length} tools: ${tools.map(t => t.name).join(', ')}`);
            resolve(tools);
          } catch (error) {
            log(`Error parsing tools response: ${error.message}`);
            resolve([]); // Return empty array instead of rejecting
          }
        });
      });
      req.on('error', (err) => {
        log(`HTTP error fetching tools: ${err.message}`);
        log(`Make sure the PostgreSQL MCP HTTP server is running on ${MCP_HTTP_URL}`);
        resolve([]); // Return empty array instead of rejecting
      });
      req.on('timeout', () => {
        req.destroy();
        log('Timeout fetching tools from HTTP server');
        resolve([]); // Return empty array instead of rejecting
      });
      req.end();
    });
  } catch (error) {
    log(`Failed to fetch tools: ${error.message}`);
    return [];
  }
}

// Process incoming JSON-RPC request
async function processRequest(line) {
  let request;
  try {
    request = JSON.parse(line);
    const method = request.method || 'unknown';
    log(`Received request: ${method} (id: ${request.id})`);
    
    let response;

    // Handle MCP protocol methods locally
    if (method === 'initialize') {
      // Fetch tools from HTTP server
      if (!toolsCache) {
        toolsCache = await fetchTools();
        log(`Loaded ${toolsCache.length} tools from HTTP server`);
      }

      response = {
        jsonrpc: '2.0',
        id: request.id,
        result: {
          protocolVersion: '2024-11-05',
          capabilities: {
            tools: {},
            prompts: {},
            resources: {}
          },
          serverInfo: {
            name: 'postgres-mcp-azure',
            version: '1.0.0'
          }
        }
      };
    } else if (method === 'tools/list') {
      // Return cached tools
      if (!toolsCache) {
        toolsCache = await fetchTools();
      }

      response = {
        jsonrpc: '2.0',
        id: request.id,
        result: {
          tools: toolsCache
        }
      };
    } else if (method === 'tools/call') {
      // Forward tool calls to HTTP server
      const toolName = request.params?.name;
      const toolArgs = request.params?.arguments || {};

      const httpResponse = await makeHttpRequest(`${MCP_HTTP_URL}/tools/call`, {
        name: toolName,
        arguments: toolArgs
      });

      response = {
        jsonrpc: '2.0',
        id: request.id,
        result: httpResponse
      };
    } else if (method === 'prompts/list') {
      // Return empty prompts list
      response = {
        jsonrpc: '2.0',
        id: request.id,
        result: {
          prompts: []
        }
      };
    } else if (method === 'resources/list') {
      // Return empty resources list
      response = {
        jsonrpc: '2.0',
        id: request.id,
        result: {
          resources: []
        }
      };
    } else if (method.startsWith('notifications/')) {
      // Ignore notifications
      log(`Ignoring notification: ${method}`);
      return;
    } else {
      // Unknown method
      response = {
        jsonrpc: '2.0',
        id: request.id,
        error: {
          code: -32601,
          message: `Method not found: ${method}`
        }
      };
    }
    
    // Send response to stdout
    console.log(JSON.stringify(response));
    log(`Response sent for ${method}`);
    
  } catch (error) {
    log(`Error: ${error.message}`);
    
    // Send JSON-RPC error response
    const errorResponse = {
      jsonrpc: '2.0',
      error: {
        code: -32603,
        message: error.message,
        data: { adapter: 'postgres-http-adapter' }
      },
      id: request?.id || null
    };
    
    console.log(JSON.stringify(errorResponse));
  }
}

// Handle stdin input
rl.on('line', (line) => {
  if (line.trim()) {
    processRequest(line.trim());
  }
});

// Handle process termination
process.on('SIGINT', () => {
  log('Received SIGINT, shutting down...');
  rl.close();
  process.exit(0);
});

process.on('SIGTERM', () => {
  log('Received SIGTERM, shutting down...');
  rl.close();
  process.exit(0);
});

// Startup message
log('PostgreSQL MCP HTTP-to-stdio adapter started');
log(`Forwarding requests to: ${MCP_HTTP_URL}`);
