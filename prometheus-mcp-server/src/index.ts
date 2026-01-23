#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";

// Prometheus configuration
const PROMETHEUS_URL = process.env.PROMETHEUS_URL || "http://localhost:9090";

interface PrometheusQueryResult {
  status: string;
  data: {
    resultType: string;
    result: Array<{
      metric: Record<string, string>;
      value?: [number, string];
      values?: Array<[number, string]>;
    }>;
  };
}

/**
 * Query Prometheus using PromQL
 */
async function queryPrometheus(
  query: string,
  time?: string
): Promise<PrometheusQueryResult> {
  const url = new URL(`${PROMETHEUS_URL}/api/v1/query`);
  url.searchParams.append("query", query);
  if (time) {
    url.searchParams.append("time", time);
  }

  const response = await fetch(url.toString());
  if (!response.ok) {
    throw new Error(`Prometheus query failed: ${response.statusText}`);
  }

  return await response.json();
}

/**
 * Query Prometheus range data
 */
async function queryRangePrometheus(
  query: string,
  start: string,
  end: string,
  step: string
): Promise<PrometheusQueryResult> {
  const url = new URL(`${PROMETHEUS_URL}/api/v1/query_range`);
  url.searchParams.append("query", query);
  url.searchParams.append("start", start);
  url.searchParams.append("end", end);
  url.searchParams.append("step", step);

  const response = await fetch(url.toString());
  if (!response.ok) {
    throw new Error(`Prometheus range query failed: ${response.statusText}`);
  }

  return await response.json();
}

/**
 * Get available metrics from Prometheus
 */
async function getMetrics(): Promise<string[]> {
  const url = new URL(`${PROMETHEUS_URL}/api/v1/label/__name__/values`);
  const response = await fetch(url.toString());
  
  if (!response.ok) {
    throw new Error(`Failed to fetch metrics: ${response.statusText}`);
  }

  const data = await response.json();
  return data.data || [];
}

/**
 * Get active targets from Prometheus
 */
async function getTargets(): Promise<any> {
  const url = new URL(`${PROMETHEUS_URL}/api/v1/targets`);
  const response = await fetch(url.toString());
  
  if (!response.ok) {
    throw new Error(`Failed to fetch targets: ${response.statusText}`);
  }

  return await response.json();
}

/**
 * Get Prometheus server configuration
 */
async function getConfig(): Promise<any> {
  const url = new URL(`${PROMETHEUS_URL}/api/v1/status/config`);
  const response = await fetch(url.toString());
  
  if (!response.ok) {
    throw new Error(`Failed to fetch config: ${response.statusText}`);
  }

  return await response.json();
}

/**
 * Format Prometheus results for display
 */
function formatResults(results: PrometheusQueryResult): string {
  if (!results.data || !results.data.result) {
    return "No data returned from query";
  }

  const formatted = results.data.result.map((result) => {
    const labels = Object.entries(result.metric)
      .map(([k, v]) => `${k}="${v}"`)
      .join(", ");
    
    if (result.value) {
      const [timestamp, value] = result.value;
      return `{${labels}} => ${value} @ ${new Date(timestamp * 1000).toISOString()}`;
    } else if (result.values) {
      const values = result.values
        .map(([ts, val]) => `  ${new Date(ts * 1000).toISOString()}: ${val}`)
        .join("\n");
      return `{${labels}}\n${values}`;
    }
    
    return `{${labels}}`;
  });

  return formatted.join("\n\n");
}

// Define available tools
const TOOLS: Tool[] = [
  {
    name: "prometheus_query",
    description: `Execute a PromQL query against Prometheus.
    
Common queries for Spring Petclinic:
- jvm_memory_used_bytes{app="customers-service"}: JVM memory usage
- http_server_requests_seconds_count{app="api-gateway"}: HTTP request count
- http_server_requests_seconds_sum{app="vets-service"}: Total request time
- rate(http_server_requests_seconds_count[5m]): Request rate per second
- up{job="petclinic-services"}: Service health status
- process_cpu_usage{app=~".*-service"}: CPU usage by service`,
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "PromQL query expression",
        },
        time: {
          type: "string",
          description: "Evaluation timestamp (optional, RFC3339 or Unix timestamp)",
        },
      },
      required: ["query"],
    },
  },
  {
    name: "prometheus_query_range",
    description: `Execute a PromQL range query for time-series data.
    
Use this to get historical metrics over a time period.
Example: Get last hour of CPU usage with 1-minute resolution`,
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "PromQL query expression",
        },
        start: {
          type: "string",
          description: "Start timestamp (RFC3339 or Unix timestamp)",
        },
        end: {
          type: "string",
          description: "End timestamp (RFC3339 or Unix timestamp)",
        },
        step: {
          type: "string",
          description: "Query resolution step (e.g., '15s', '1m', '5m')",
        },
      },
      required: ["query", "start", "end", "step"],
    },
  },
  {
    name: "prometheus_list_metrics",
    description: "List all available metrics in Prometheus. Useful for discovering what metrics are being collected from the Spring Petclinic application.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "prometheus_get_targets",
    description: "Get the status of all configured scrape targets. Shows which services are being monitored and their health.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "prometheus_get_config",
    description: "Retrieve the current Prometheus server configuration including scrape configs.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "prometheus_petclinic_health",
    description: "Check the health status of all Spring Petclinic microservices",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
  {
    name: "prometheus_petclinic_metrics",
    description: "Get comprehensive metrics summary for Spring Petclinic services including memory, CPU, HTTP requests, and database connections",
    inputSchema: {
      type: "object",
      properties: {
        service: {
          type: "string",
          description: "Specific service name (optional): customers-service, visits-service, vets-service, api-gateway",
        },
      },
    },
  },
];

// Create MCP server
const server = new Server(
  {
    name: "prometheus-mcp-server",
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
      case "prometheus_query": {
        const { query, time } = args as { query: string; time?: string };
        const results = await queryPrometheus(query, time);
        return {
          content: [
            {
              type: "text",
              text: formatResults(results),
            },
          ],
        };
      }

      case "prometheus_query_range": {
        const { query, start, end, step } = args as {
          query: string;
          start: string;
          end: string;
          step: string;
        };
        const results = await queryRangePrometheus(query, start, end, step);
        return {
          content: [
            {
              type: "text",
              text: formatResults(results),
            },
          ],
        };
      }

      case "prometheus_list_metrics": {
        const metrics = await getMetrics();
        return {
          content: [
            {
              type: "text",
              text: `Available metrics (${metrics.length} total):\n\n${metrics.join("\n")}`,
            },
          ],
        };
      }

      case "prometheus_get_targets": {
        const targets = await getTargets();
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(targets, null, 2),
            },
          ],
        };
      }

      case "prometheus_get_config": {
        const config = await getConfig();
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(config, null, 2),
            },
          ],
        };
      }

      case "prometheus_petclinic_health": {
        const healthQuery = 'up{job="petclinic-services"}';
        const results = await queryPrometheus(healthQuery);
        
        const healthStatus = results.data.result.map((r) => {
          const app = r.metric.app || "unknown";
          const status = r.value?.[1] === "1" ? "✅ UP" : "❌ DOWN";
          return `${app}: ${status}`;
        });

        return {
          content: [
            {
              type: "text",
              text: `Spring Petclinic Services Health:\n\n${healthStatus.join("\n")}`,
            },
          ],
        };
      }

      case "prometheus_petclinic_metrics": {
        const { service } = args as { service?: string };
        const serviceFilter = service ? `{app="${service}"}` : '{app=~".*-service|api-gateway"}';
        
        const queries = {
          memory: `jvm_memory_used_bytes${serviceFilter}`,
          cpu: `process_cpu_usage${serviceFilter}`,
          requests: `rate(http_server_requests_seconds_count${serviceFilter}[5m])`,
          errors: `rate(http_server_requests_seconds_count{status=~"5..",${serviceFilter.slice(1)}}[5m])`,
        };

        const results = await Promise.all(
          Object.entries(queries).map(async ([name, query]) => {
            try {
              const data = await queryPrometheus(query);
              return { name, data: formatResults(data) };
            } catch (error) {
              return { name, data: `Error: ${error}` };
            }
          })
        );

        const summary = results.map((r) => `${r.name.toUpperCase()}:\n${r.data}`).join("\n\n");

        return {
          content: [
            {
              type: "text",
              text: `Spring Petclinic Metrics${service ? ` - ${service}` : ""}:\n\n${summary}`,
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
  console.error("Prometheus MCP Server running on stdio");
  console.error(`Connected to Prometheus at: ${PROMETHEUS_URL}`);
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
