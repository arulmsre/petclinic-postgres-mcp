#!/usr/bin/env node
/**
 * MCP HTTP Bridge
 *
 * Wraps stdio-based MCP servers with an HTTP interface for deployment to cloud services.
 * Supports Server-Sent Events (SSE) for real-time communication.
 */
import express from 'express';
import cors from 'cors';
import { spawn } from 'child_process';
import { createInterface } from 'readline';
const app = express();
const PORT = process.env.PORT || 3000;
const MCP_COMMAND = process.env.MCP_COMMAND || 'node';
const MCP_ARGS = process.env.MCP_ARGS ? process.env.MCP_ARGS.split(',') : ['dist/index.js'];
const MCP_CWD = process.env.MCP_CWD || process.cwd();
// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
// MCP Server Process
let mcpProcess = null;
let messageId = 0;
const pendingRequests = new Map();
/**
 * Start the MCP server process
 */
function startMcpServer() {
    console.log(`Starting MCP server: ${MCP_COMMAND} ${MCP_ARGS.join(' ')}`);
    console.log(`Working directory: ${MCP_CWD}`);
    mcpProcess = spawn(MCP_COMMAND, MCP_ARGS, {
        cwd: MCP_CWD,
        env: { ...process.env },
        stdio: ['pipe', 'pipe', 'pipe']
    });
    // Handle stdout (MCP responses)
    const rl = createInterface({
        input: mcpProcess.stdout,
        crlfDelay: Infinity
    });
    rl.on('line', (line) => {
        try {
            const response = JSON.parse(line);
            const id = response.id;
            if (id !== undefined && pendingRequests.has(id)) {
                const { resolve, timeout } = pendingRequests.get(id);
                clearTimeout(timeout);
                pendingRequests.delete(id);
                resolve(response);
            }
            else {
                // Notification or unmatched response
                console.log('MCP notification:', line);
            }
        }
        catch (err) {
            console.error('Failed to parse MCP response:', line, err);
        }
    });
    // Handle stderr
    mcpProcess.stderr.on('data', (data) => {
        console.error('MCP stderr:', data.toString());
    });
    // Handle process exit
    mcpProcess.on('exit', (code, signal) => {
        console.error(`MCP process exited with code ${code}, signal ${signal}`);
        mcpProcess = null;
        // Reject all pending requests
        for (const [id, { reject, timeout }] of pendingRequests.entries()) {
            clearTimeout(timeout);
            reject(new Error('MCP process terminated'));
        }
        pendingRequests.clear();
        // Restart after delay
        setTimeout(() => {
            console.log('Restarting MCP server...');
            startMcpServer();
        }, 5000);
    });
    // Handle process errors
    mcpProcess.on('error', (err) => {
        console.error('MCP process error:', err);
    });
}
/**
 * Send a JSON-RPC request to the MCP server
 */
function sendToMcp(method, params) {
    return new Promise((resolve, reject) => {
        if (!mcpProcess || !mcpProcess.stdin) {
            reject(new Error('MCP server not running'));
            return;
        }
        const id = messageId++;
        const request = {
            jsonrpc: '2.0',
            id,
            method,
            params: params || {}
        };
        // Set timeout
        const timeout = setTimeout(() => {
            pendingRequests.delete(id);
            reject(new Error(`Request timeout for method: ${method}`));
        }, 30000); // 30 second timeout
        pendingRequests.set(id, { resolve, reject, timeout });
        try {
            mcpProcess.stdin.write(JSON.stringify(request) + '\n');
        }
        catch (err) {
            clearTimeout(timeout);
            pendingRequests.delete(id);
            reject(err);
        }
    });
}
/**
 * Health check endpoint
 */
app.get('/health', (req, res) => {
    const healthy = mcpProcess !== null && !mcpProcess.killed;
    res.status(healthy ? 200 : 503).json({
        status: healthy ? 'healthy' : 'unhealthy',
        mcpServerRunning: healthy,
        uptime: process.uptime(),
        pendingRequests: pendingRequests.size
    });
});
/**
 * Initialize endpoint - call this after MCP server starts
 */
app.post('/initialize', async (req, res) => {
    try {
        const { clientInfo, capabilities } = req.body;
        const response = await sendToMcp('initialize', {
            protocolVersion: '2024-11-05',
            clientInfo: clientInfo || {
                name: 'mcp-http-bridge',
                version: '1.0.0'
            },
            capabilities: capabilities || {}
        });
        res.json(response);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
});
/**
 * List available tools
 */
app.get('/tools', async (req, res) => {
    try {
        const response = await sendToMcp('tools/list');
        res.json(response);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
});
/**
 * Call a tool
 */
app.post('/tools/call', async (req, res) => {
    try {
        const { name, arguments: args } = req.body;
        const response = await sendToMcp('tools/call', {
            name,
            arguments: args || {}
        });
        res.json(response);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
});
/**
 * List available resources
 */
app.get('/resources', async (req, res) => {
    try {
        const response = await sendToMcp('resources/list');
        res.json(response);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
});
/**
 * Read a resource
 */
app.post('/resources/read', async (req, res) => {
    try {
        const { uri } = req.body;
        const response = await sendToMcp('resources/read', { uri });
        res.json(response);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
});
/**
 * List available prompts
 */
app.get('/prompts', async (req, res) => {
    try {
        const response = await sendToMcp('prompts/list');
        res.json(response);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
});
/**
 * Get a prompt
 */
app.post('/prompts/get', async (req, res) => {
    try {
        const { name, arguments: args } = req.body;
        const response = await sendToMcp('prompts/get', {
            name,
            arguments: args || {}
        });
        res.json(response);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
});
/**
 * Generic RPC endpoint - forward any method
 */
app.post('/rpc', async (req, res) => {
    try {
        const { method, params } = req.body;
        if (!method) {
            res.status(400).json({ error: 'Method is required' });
            return;
        }
        const response = await sendToMcp(method, params);
        res.json(response);
    }
    catch (err) {
        res.status(500).json({ error: err.message });
    }
});
/**
 * Server info endpoint
 */
app.get('/', (req, res) => {
    res.json({
        service: 'MCP HTTP Bridge',
        version: '1.0.0',
        mcp: {
            command: MCP_COMMAND,
            args: MCP_ARGS,
            cwd: MCP_CWD,
            running: mcpProcess !== null && !mcpProcess.killed
        },
        endpoints: {
            health: 'GET /health',
            initialize: 'POST /initialize',
            tools: 'GET /tools',
            toolsCall: 'POST /tools/call',
            resources: 'GET /resources',
            resourcesRead: 'POST /resources/read',
            prompts: 'GET /prompts',
            promptsGet: 'POST /prompts/get',
            rpc: 'POST /rpc'
        }
    });
});
// Start MCP server
startMcpServer();
// Start HTTP server
app.listen(PORT, () => {
    console.log(`MCP HTTP Bridge listening on port ${PORT}`);
    console.log(`MCP server command: ${MCP_COMMAND} ${MCP_ARGS.join(' ')}`);
    console.log(`Working directory: ${MCP_CWD}`);
});
// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully');
    if (mcpProcess) {
        mcpProcess.kill();
    }
    process.exit(0);
});
process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully');
    if (mcpProcess) {
        mcpProcess.kill();
    }
    process.exit(0);
});
