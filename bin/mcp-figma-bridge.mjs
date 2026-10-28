#!/usr/bin/env node
// stdio-to-HTTP MCP bridge for the Figma remote MCP server.
// Node's global fetch must be proxied: start with NODE_USE_ENV_PROXY=1 and
// HTTPS_PROXY pointing at a local proxy that can reach mcp.figma.com.

import { createInterface } from 'node:readline';

const ENDPOINT = 'https://mcp.figma.com/mcp';
const AUTHORIZATION = process.env.FIGMA_AUTHORIZATION;
let sessionId;

if (!AUTHORIZATION) {
  console.error('mcp-figma-bridge: FIGMA_AUTHORIZATION is not set (full value of the Authorization header, e.g. "Bearer ey...")');
  process.exit(1);
}

createInterface({ input: process.stdin }).on('line', (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  let message;
  try {
    message = JSON.parse(trimmed);
  } catch (error) {
    console.error(`mcp-figma-bridge: unparseable stdin line: ${error.message}`);
    return;
  }
  forward(message).catch((error) => {
    if (message.id === undefined) {
      console.error(`mcp-figma-bridge: ${error.message}`);
      return;
    }
    emit({ jsonrpc: '2.0', id: message.id, error: { code: -32603, message: String(error.message || error) } });
  });
}).on('close', () => process.exit(0));

async function forward(message) {
  const headers = {
    'Content-Type': 'application/json',
    Accept: 'application/json, text/event-stream',
    Authorization: AUTHORIZATION,
  };
  if (sessionId) headers['Mcp-Session-Id'] = sessionId;
  const response = await fetch(ENDPOINT, { method: 'POST', headers, body: JSON.stringify(message) });
  const freshSessionId = response.headers.get('mcp-session-id');
  if (freshSessionId) sessionId = freshSessionId;
  if (message.id === undefined) return;
  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(`figma mcp http ${response.status}: ${body.slice(0, 300)}`);
  }
  const contentType = response.headers.get('content-type') ?? '';
  if (contentType.includes('text/event-stream')) {
    emit(await readSseResponse(response, message.id));
  } else {
    emit(JSON.parse(await response.text()));
  }
}

async function readSseResponse(response, id) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });
    let newlineAt;
    while ((newlineAt = buffer.indexOf('\n')) !== -1) {
      const line = buffer.slice(0, newlineAt).trim();
      buffer = buffer.slice(newlineAt + 1);
      if (!line.startsWith('data:')) continue;
      try {
        const parsed = JSON.parse(line.slice(5).trim());
        if (parsed.id === id) {
          reader.cancel().catch(() => {});
          return parsed;
        }
      } catch {
        // a comment or keep-alive frame, not JSON
      }
    }
  }
  throw new Error(`figma mcp: sse stream ended without a response to request ${id}`);
}

function emit(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}
