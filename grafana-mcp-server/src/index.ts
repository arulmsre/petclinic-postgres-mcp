#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";

// Grafana configuration
const GRAFANA_URL = process.env.GRAFANA_URL || "http://20.81.80.200";
const GRAFANA_USER = process.env.GRAFANA_USER || "admin";
const GRAFANA_PASSWORD = process.env.GRAFANA_PASSWORD || "admin";

// Base64 encode credentials for Basic Auth
const authHeader = `Basic ${Buffer.from(`${GRAFANA_USER}:${GRAFANA_PASSWORD}`).toString('base64')}`;

/**
 * Make authenticated request to Grafana API
 */
async function grafanaRequest(path: string, options: RequestInit = {}): Promise<any> {
  const url = `${GRAFANA_URL}${path}`;
  
  const response = await fetch(url, {
    ...options,
    headers: {
      'Authorization': authHeader,
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });

  if (!response.ok) {
    throw new Error(`Grafana API error: ${response.status} ${response.statusText}`);
  }

  return await response.json();
}

/**
 * List all dashboards
 */
async function listDashboards(): Promise<any[]> {
  const result = await grafanaRequest('/api/search?type=dash-db');
  return result;
}

/**
 * Get dashboard by UID
 */
async function getDashboard(uid: string): Promise<any> {
  const result = await grafanaRequest(`/api/dashboards/uid/${uid}`);
  return result;
}

/**
 * Search dashboards
 */
async function searchDashboards(query: string): Promise<any[]> {
  const result = await grafanaRequest(`/api/search?query=${encodeURIComponent(query)}`);
  return result;
}

/**
 * Get datasources
 */
async function getDatasources(): Promise<any[]> {
  const result = await grafanaRequest('/api/datasources');
  return result;
}

/**
 * Query Prometheus through Grafana
 */
async function queryPrometheus(query: string, datasourceId: number = 1): Promise<any> {
  const result = await grafanaRequest('/api/ds/query', {
    method: 'POST',
    body: JSON.stringify({
      queries: [
        {
          refId: 'A',
          expr: query,
          datasource: { type: 'prometheus', uid: datasourceId },
        },
      ],
    }),
  });
  return result;
}

/**
 * Get health status
 */
async function getHealth(): Promise<any> {
  const result = await grafanaRequest('/api/health');
  return result;
}

/**
 * Get organization info
 */
async function getOrg(): Promise<any> {
  const result = await grafanaRequest('/api/org');
  return result;
}

/**
 * Get annotations
 */
async function getAnnotations(from?: number, to?: number): Promise<any[]> {
  let path = '/api/annotations';
  const params = new URLSearchParams();
  
  if (from) params.append('from', from.toString());
  if (to) params.append('to', to.toString());
  
  if (params.toString()) {
    path += `?${params.toString()}`;
  }
  
  const result = await grafanaRequest(path);
  return result;
}

// Define available tools
const TOOLS: Tool[] = [
  {
    name: "grafana_list_dashboards",
    description: "List all available Grafana dashboards with their titles, UIDs, and folders.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "grafana_search_dashboards",
    description: "Search for dashboards by name or tag.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Search query (dashboard name, tag, etc.)",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "grafana_get_dashboard",
    description: "Get detailed information about a specific dashboard including all panels and queries.",
    inputSchema: {
      type: "object",
      properties: {
        uid: {
          type: "string",
          description: "Dashboard UID (get from list_dashboards)",
        },
      },
      required: ["uid"],
    },
  },
  {
    name: "grafana_list_datasources",
    description: "List all configured Grafana data sources (Prometheus, Loki, Tempo, etc.).",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "grafana_query_prometheus",
    description: "Execute a PromQL query through Grafana's Prometheus datasource.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "PromQL query expression",
        },
        datasourceId: {
          type: "number",
          description: "Prometheus datasource ID (optional, default: 1)",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "grafana_get_health",
    description: "Check Grafana server health status.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "grafana_get_org",
    description: "Get current organization information.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "grafana_get_annotations",
    description: "Get annotations (events, incidents, deployments marked on graphs).",
    inputSchema: {
      type: "object",
      properties: {
        from: {
          type: "number",
          description: "Start time (Unix timestamp in milliseconds)",
        },
        to: {
          type: "number",
          description: "End time (Unix timestamp in milliseconds)",
        },
      },
    },
  },
  {
    name: "grafana_petclinic_overview",
    description: "Get a comprehensive overview of Spring Petclinic monitoring including active dashboards and key metrics.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
];

// Create MCP server
const server = new Server(
  {
    name: "grafana-mcp-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: TOOLS };
});

// Handle tool execution
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "grafana_list_dashboards": {
        const dashboards = await listDashboards();
        const formatted = dashboards.map((d) => 
          `- ${d.title} (UID: ${d.uid}, Folder: ${d.folderTitle || 'General'})`
        ).join('\n');
        
        return {
          content: [
            {
              type: "text",
              text: `Found ${dashboards.length} dashboards:\n\n${formatted}`,
            },
          ],
        };
      }

      case "grafana_search_dashboards": {
        const { query } = args as { query: string };
        const results = await searchDashboards(query);
        
        if (results.length === 0) {
          return {
            content: [
              {
                type: "text",
                text: `No dashboards found matching: "${query}"`,
              },
            ],
          };
        }
        
        const formatted = results.map((d) => 
          `- ${d.title} (UID: ${d.uid})`
        ).join('\n');
        
        return {
          content: [
            {
              type: "text",
              text: `Found ${results.length} dashboards matching "${query}":\n\n${formatted}`,
            },
          ],
        };
      }

      case "grafana_get_dashboard": {
        const { uid } = args as { uid: string };
        const dashboard = await getDashboard(uid);
        
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(dashboard, null, 2),
            },
          ],
        };
      }

      case "grafana_list_datasources": {
        const datasources = await getDatasources();
        const formatted = datasources.map((ds) => 
          `- ${ds.name} (Type: ${ds.type}, ID: ${ds.id}, Default: ${ds.isDefault})`
        ).join('\n');
        
        return {
          content: [
            {
              type: "text",
              text: `Configured datasources:\n\n${formatted}`,
            },
          ],
        };
      }

      case "grafana_query_prometheus": {
        const { query, datasourceId } = args as { query: string; datasourceId?: number };
        const result = await queryPrometheus(query, datasourceId);
        
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case "grafana_get_health": {
        const health = await getHealth();
        return {
          content: [
            {
              type: "text",
              text: `Grafana Health: ${health.database === 'ok' ? '✅ OK' : '❌ ERROR'}\nDatabase: ${health.database}\nVersion: ${health.version || 'N/A'}`,
            },
          ],
        };
      }

      case "grafana_get_org": {
        const org = await getOrg();
        return {
          content: [
            {
              type: "text",
              text: `Organization: ${org.name}\nID: ${org.id}`,
            },
          ],
        };
      }

      case "grafana_get_annotations": {
        const { from, to } = args as { from?: number; to?: number };
        const annotations = await getAnnotations(from, to);
        
        if (annotations.length === 0) {
          return {
            content: [
              {
                type: "text",
                text: "No annotations found in the specified time range.",
              },
            ],
          };
        }
        
        const formatted = annotations.map((a) => 
          `[${new Date(a.time).toISOString()}] ${a.text}`
        ).join('\n');
        
        return {
          content: [
            {
              type: "text",
              text: `Found ${annotations.length} annotations:\n\n${formatted}`,
            },
          ],
        };
      }

      case "grafana_petclinic_overview": {
        const [dashboards, datasources, health] = await Promise.all([
          listDashboards(),
          getDatasources(),
          getHealth(),
        ]);
        
        const overview = `
Spring Petclinic Grafana Overview
==================================

Health Status: ${health.database === 'ok' ? '✅ OK' : '❌ ERROR'}
Grafana Version: ${health.version || 'N/A'}

Data Sources (${datasources.length}):
${datasources.map((ds) => `  - ${ds.name} (${ds.type})`).join('\n')}

Dashboards (${dashboards.length}):
${dashboards.map((d) => `  - ${d.title}`).join('\n')}

Access URL: ${GRAFANA_URL}
`.trim();
        
        return {
          content: [
            {
              type: "text",
              text: overview,
            },
          ],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return {
      content: [
        {
          type: "text",
          text: `Error executing ${name}: ${errorMessage}`,
        },
      ],
      isError: true,
    };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Grafana MCP Server running on stdio");
  console.error(`Connected to Grafana at: ${GRAFANA_URL}`);
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
