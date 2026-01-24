# PostgreSQL MCP Server for Azure

Model Context Protocol (MCP) server for Azure PostgreSQL database integration with the Spring PetClinic application.

## Features

- Execute SQL queries on Azure PostgreSQL
- List database tables and schemas
- Get table statistics and metadata
- PetClinic-specific metrics and reporting
- Secure connection with SSL support

## Available Tools

### postgres_query
Execute SQL queries on the Azure PostgreSQL database.
- **query**: SQL query to execute (SELECT recommended)
- **params**: Optional query parameters for parameterized queries

### postgres_list_tables
List all tables in the current database schema.

### postgres_get_schema
Get schema information for a specific table.
- **table_name**: Name of the table

### postgres_get_table_stats
Get statistics for a specific table.
- **table_name**: Name of the table

### postgres_petclinic_metrics
Get PetClinic-specific metrics including owners, pets, vets, visits, and recent activity.

## Configuration

Configure via environment variables:

```bash
PG_HOST=your-server.postgres.database.azure.com
PG_PORT=5432
PG_DATABASE=petclinic
PG_USER=adminuser@your-server
PG_PASSWORD=your-password
PG_SSL=true  # Enable SSL for Azure (recommended)
```

## Installation

```bash
npm install
npm run build
```

## Running Locally

### Stdio Mode (for MCP)
```bash
node dist/index.js
```

### Via HTTP Bridge
```bash
# Start HTTP bridge on port 8092
cd ../mcp-http-bridge
PORT=8092 \
MCP_COMMAND=node \
MCP_ARGS=../postgres-mcp-server/dist/index.js \
MCP_CWD=../postgres-mcp-server \
PG_HOST=your-server.postgres.database.azure.com \
PG_DATABASE=petclinic \
PG_USER=adminuser@your-server \
PG_PASSWORD=your-password \
npm start
```

## Azure PostgreSQL Setup

1. Create Azure PostgreSQL Flexible Server
2. Configure firewall rules to allow connections
3. Create the petclinic database:
```sql
CREATE DATABASE petclinic;
```

4. Initialize schema with PetClinic schema:
```bash
psql -h your-server.postgres.database.azure.com -U adminuser@your-server -d petclinic -f schema.sql
```

## Docker Build

```bash
docker build -t postgres-mcp-server .
```

## Integration with Claude Desktop

Add to Claude Desktop config (`%APPDATA%\Claude\claude_desktop_config.json`):

### Via Adapter (Recommended)
```json
{
  "mcpServers": {
    "postgres-azure": {
      "command": "node",
      "args": ["D:\\path\\to\\mcp-http-adapter\\postgres-adapter.js"]
    }
  }
}
```

### Direct Stdio
```json
{
  "mcpServers": {
    "postgres-azure": {
      "command": "node",
      "args": ["D:\\path\\to\\postgres-mcp-server\\dist\\index.js"],
      "env": {
        "PG_HOST": "your-server.postgres.database.azure.com",
        "PG_DATABASE": "petclinic",
        "PG_USER": "adminuser@your-server",
        "PG_PASSWORD": "your-password"
      }
    }
  }
}
```

## Security Notes

- Always use SSL for Azure PostgreSQL connections
- Store credentials securely (use Azure Key Vault in production)
- Limit query permissions appropriately
- Use parameterized queries to prevent SQL injection
- Consider read-only database users for MCP access

## PetClinic Database Schema

The server expects the standard PetClinic schema with tables:
- `owners`: Pet owners
- `pets`: Pets and their owners
- `types`: Pet types (cat, dog, etc.)
- `vets`: Veterinarians
- `specialties`: Vet specialties
- `vet_specialties`: Junction table
- `visits`: Vet visits

## Troubleshooting

### Connection Issues
- Verify Azure PostgreSQL firewall allows your IP
- Check SSL settings match Azure requirements
- Ensure credentials are correct
- Verify database exists

### Query Errors
- Check table names match schema
- Verify user has SELECT permissions
- Use parameterized queries for safety

## License

MIT
