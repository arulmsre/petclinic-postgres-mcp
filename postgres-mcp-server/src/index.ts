#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { Client } from 'pg';

// Azure PostgreSQL configuration
const PG_HOST = process.env.PG_HOST || 'your-server.postgres.database.azure.com';
const PG_PORT = parseInt(process.env.PG_PORT || '5432');
const PG_DATABASE = process.env.PG_DATABASE || 'petclinic';
const PG_USER = process.env.PG_USER || 'adminuser@your-server';
const PG_PASSWORD = process.env.PG_PASSWORD || '';
const PG_SSL = process.env.PG_SSL !== 'false'; // Default to true for Azure

// PostgreSQL client
let pgClient: Client | null = null;

/**
 * Connect to PostgreSQL database
 */
async function connectToPostgres(): Promise<Client> {
  if (pgClient) {
    return pgClient;
  }

  pgClient = new Client({
    host: PG_HOST,
    port: PG_PORT,
    database: PG_DATABASE,
    user: PG_USER,
    password: PG_PASSWORD,
    ssl: PG_SSL ? { rejectUnauthorized: false } : false,
  });

  await pgClient.connect();
  console.error(`Connected to PostgreSQL at: ${PG_HOST}:${PG_PORT}/${PG_DATABASE}`);
  return pgClient;
}

/**
 * Execute a SQL query
 */
async function executeQuery(query: string, params: any[] = []): Promise<any> {
  const client = await connectToPostgres();
  const result = await client.query(query, params);
  return result.rows;
}

/**
 * Get table schema information
 */
async function getTableSchema(tableName: string): Promise<any> {
  const query = `
    SELECT 
      column_name, 
      data_type, 
      is_nullable,
      column_default
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = $1
    ORDER BY ordinal_position;
  `;
  return executeQuery(query, [tableName]);
}

/**
 * List all tables in the database
 */
async function listTables(): Promise<any> {
  const query = `
    SELECT 
      table_name,
      table_type
    FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name;
  `;
  return executeQuery(query);
}

/**
 * Get row count for a table
 */
async function getTableRowCount(tableName: string): Promise<number> {
  const result = await executeQuery(`SELECT COUNT(*) as count FROM ${tableName}`);
  return parseInt(result[0].count);
}

/**
 * Get PetClinic-specific metrics
 */
async function getPetClinicMetrics(): Promise<any> {
  const queries = {
    totalOwners: `SELECT COUNT(*) as count FROM owners`,
    totalPets: `SELECT COUNT(*) as count FROM pets`,
    totalVets: `SELECT COUNT(*) as count FROM vets`,
    totalVisits: `SELECT COUNT(*) as count FROM visits`,
    recentVisits: `
      SELECT v.visit_date, p.name as pet_name, o.first_name, o.last_name, v.description
      FROM visits v
      JOIN pets p ON v.pet_id = p.id
      JOIN owners o ON p.owner_id = o.id
      ORDER BY v.visit_date DESC
      LIMIT 10
    `,
    petsByType: `
      SELECT t.name as type, COUNT(*) as count
      FROM pets p
      JOIN types t ON p.type_id = t.id
      GROUP BY t.name
      ORDER BY count DESC
    `
  };

  const results: any = {};
  for (const [key, query] of Object.entries(queries)) {
    try {
      results[key] = await executeQuery(query);
    } catch (error: any) {
      results[key] = { error: error.message };
    }
  }

  return results;
}

// Create MCP server
const server = new Server(
  {
    name: "postgres-mcp-azure",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Define available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "postgres_query",
        description: "Execute a SQL query on the Azure PostgreSQL database. Returns query results as JSON.",
        inputSchema: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "SQL query to execute (SELECT statements recommended)",
            },
            params: {
              type: "array",
              items: { type: "string" },
              description: "Query parameters for parameterized queries (optional)",
            },
          },
          required: ["query"],
        },
      },
      {
        name: "postgres_list_tables",
        description: "List all tables in the current database schema.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "postgres_get_schema",
        description: "Get the schema (columns, types, constraints) for a specific table.",
        inputSchema: {
          type: "object",
          properties: {
            table_name: {
              type: "string",
              description: "Name of the table to get schema for",
            },
          },
          required: ["table_name"],
        },
      },
      {
        name: "postgres_get_table_stats",
        description: "Get statistics for a specific table (row count, etc.).",
        inputSchema: {
          type: "object",
          properties: {
            table_name: {
              type: "string",
              description: "Name of the table to get stats for",
            },
          },
          required: ["table_name"],
        },
      },
      {
        name: "postgres_petclinic_metrics",
        description: "Get PetClinic-specific metrics including owners, pets, vets, visits, and recent activity.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "postgres_query": {
        const query = (args as any).query;
        const params = (args as any).params || [];
        const results = await executeQuery(query, params);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(results, null, 2),
            },
          ],
        };
      }

      case "postgres_list_tables": {
        const tables = await listTables();
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(tables, null, 2),
            },
          ],
        };
      }

      case "postgres_get_schema": {
        const tableName = (args as any).table_name;
        const schema = await getTableSchema(tableName);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(schema, null, 2),
            },
          ],
        };
      }

      case "postgres_get_table_stats": {
        const tableName = (args as any).table_name;
        const rowCount = await getTableRowCount(tableName);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify({ table_name: tableName, row_count: rowCount }, null, 2),
            },
          ],
        };
      }

      case "postgres_petclinic_metrics": {
        const metrics = await getPetClinicMetrics();
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(metrics, null, 2),
            },
          ],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error: any) {
    return {
      content: [
        {
          type: "text",
          text: `Error: ${error.message}`,
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
  console.error("PostgreSQL MCP Server running on stdio");
  
  // Test connection
  try {
    await connectToPostgres();
  } catch (error: any) {
    console.error(`Warning: Could not connect to PostgreSQL: ${error.message}`);
    console.error('Server will continue but database operations will fail until connection is established.');
  }
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
