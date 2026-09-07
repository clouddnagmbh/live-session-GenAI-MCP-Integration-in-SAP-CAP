#!/usr/bin/env bash
# Minimal MCP client: POST one JSON-RPC call and unwrap the SSE frame.
# Deterministic, no Node version floor, no Inspector needed.
curl -sS -X POST "${MCP_URL:-http://localhost:4004/mcp/travel}" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H "Authorization: Basic $(printf "${MCP_USER:-alice}:${MCP_PASS:-}" | base64)" \
  -d "$1" | sed -n 's/^data: //p'
