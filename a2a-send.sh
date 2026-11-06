#!/usr/bin/env bash
# Minimal A2A client: send one user message to a CAP agent and print the task.
# Usage: ./a2a-send.sh "list three travels with their agency"
curl -sS -X POST "${A2A_URL:-http://localhost:4004/a2a/travel-agent}" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Basic $(printf "${A2A_USER:-alice}:${A2A_PASS:-}" | base64)" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"message/send\",\"params\":{\"message\":{\"role\":\"user\",\"kind\":\"message\",\"messageId\":\"$(date +%s)\",\"parts\":[{\"kind\":\"text\",\"text\":$(printf '%s' "$1" | jq -Rs .)}]}}}"
