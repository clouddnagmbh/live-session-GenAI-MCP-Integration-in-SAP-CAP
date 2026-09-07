#!/usr/bin/env bash
set -u
cd "$(git rev-parse --show-toplevel)"
PORT=4014
AUTH="Authorization: Basic $(printf 'alice:' | base64)"
rpc() { curl -sS -m 20 -X POST "http://localhost:$PORT/mcp/$1" -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' -H "$AUTH" -d "$2" | sed -n 's/^data: //p'; }

BRANCHES=(main 01-recommendations-mock 02-recommendations-control 03-aicore-service
  04-genai-orchestration 05-vector-rag 06-mcp-basics 07-mcp-query 08-mcp-actions
  09-mcp-security 10-agent-clients 11-genai-mcp-together)

for b in "${BRANCHES[@]}"; do
  git checkout -q "$b" 2>/dev/null
  npm ci --silent >/dev/null 2>&1
  if ! npx cds compile db srv app --to csn >/dev/null 2>/tmp/ce.txt; then
    printf '%-28s COMPILE FAIL: %s\n' "$b" "$(head -1 /tmp/ce.txt)"; continue
  fi
  lsof -ti tcp:$PORT | xargs -r kill -9 2>/dev/null; sleep 1
  npx cds serve --port $PORT >/tmp/v.log 2>&1 &
  SP=$!
  up=no
  for i in $(seq 1 60); do curl -sf -m 2 -o /dev/null "http://localhost:$PORT/" 2>/dev/null && { up=yes; break; }; sleep 0.5; done
  if [ "$up" != yes ]; then printf '%-28s SERVER FAIL: %s\n' "$b" "$(grep -iE 'error' /tmp/v.log|head -1)"; kill -9 $SP 2>/dev/null; continue
  fi

  note=""
  # OData works on every branch
  od=$(curl -sS -m 10 -u alice: "http://localhost:$PORT/odata/v4/travel/Travels?\$top=1&\$select=ID" | grep -c '"ID"')
  note="odata=$od"
  # branch-specific checks
  case "$b" in
    01-*|02-*) n=$(curl -sS -m 10 -u alice: "http://localhost:$PORT/odata/v4/travel/\$metadata" | grep -c SAP_Recommendations); note="$note recs=$n";;
    03-*) p=$(curl -sS -m 15 -u alice: -X POST "http://localhost:$PORT/odata/v4/aicore-demo/predictTravel" -H 'Content-Type: application/json' -d '{"description":"x","contextRows":50}' | grep -c predictions); note="$note predict=$p";;
    04-*) s=$(curl -sS -m 15 -u alice: "http://localhost:$PORT/odata/v4/travel-assistant/summarize(travelID=1)" | grep -c '"summary"'); note="$note summarize=$s";;
    05-*) r=$(curl -sS -m 20 -u alice: "http://localhost:$PORT/odata/v4/travel-assistant/askAgencies(question='opera')" | grep -c '"answer"'); note="$note rag=$r";;
    06-*|07-*) t=$(rpc travel '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | jq -r '[.result.tools[].name]|join(",")'); note="$note tools=$t";;
    08-*) t=$(rpc travel '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | jq -r '[.result.tools[].name]|join(",")'); note="$note tools=$t";;
    09-*|10-*|11-*) t=$(rpc travel-agent '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | jq -r '[.result.tools[].name]|join(",")'); note="$note agentTools=$t";;
  esac
  printf '%-28s OK   %s\n' "$b" "$note"
  kill -TERM $SP 2>/dev/null; sleep 1; kill -9 $SP 2>/dev/null
done
lsof -ti tcp:$PORT | xargs -r kill -9 2>/dev/null
git checkout -q main
