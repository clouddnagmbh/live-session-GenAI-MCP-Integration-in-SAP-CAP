# Runbook — GenAI & MCP Integration in SAP CAP (120 min, November 2026)

Deck: `GenAI_MCP_Integration_in_SAP_CAP_2026-11.pptx` (74 slides). Every demo
slide carries the same four lines in its speaker notes: commands, payoff,
fallback, reset. This file is the long form.

## Pre-flight (the evening before)

```bash
nvm use 22                     # .nvmrc; Inspector 2.14 needs ^22.23.4 || ^24.22.1
npm i -g @sap/cds-dk@10        # 10.2.x
for b in main 01-recommendations-mock 02-recommendations-control 03-aicore-service \
         04-genai-orchestration 06-mcp-basics 07-mcp-query 08-mcp-actions \
         09-mcp-security 10-agent-clients 11-genai-mcp-together 12-cap-agent; do
  git checkout -q $b && npm ci --no-audit --no-fund || break
done                           # 12 adds 72 packages — never install live
git checkout 01-recommendations-mock
cp ~/.claude.json ~/.claude.json.backup
lsof -i :4004                  # must be EMPTY — see "Port 4004" below
```

`node_modules` of branch 12 is a superset of every other branch, so one final
`git checkout 12-cap-agent && npm ci` is enough for the whole chain. Plugins
load from `package.json` dependencies only, so the extra packages are inert on
earlier branches.

## Timing

| min | part | slides | branch |
|---|---|---|---|
| 0–10 | 1 · CDS model as your AI contract | 8–15 | main |
| 10–50 | 2 · SAP-RPT-1 and generative AI (Demos 1–3) | 16–40 | 01 02 03 04 |
| 50–57 | break (slide 41) | 41 | checkout 06 meanwhile |
| 57–107 | 3 · MCP, agents and governance (Demos 4–8) | 42–65 | 06 07 08 09 10 11 12 |
| 107–110 | summary + resources | 66–72 | — |
| 110–120 | Q&A | 73–74 | — |

Marquee beats: Demo 2 payload (~30), Demo 3 profile switch (~45), Demo 5
validation error (~70), Demo 6 leak (~85), Demo 8 agent (~100).

## Before every demo

```bash
lsof -ti tcp:4004 | xargs kill -9      # a stale server answers silently
git checkout <branch> && cds watch
```

## Demo 1 — slide 22 · branch 01

- Open http://localhost:4004/$fiori-preview/TravelService/Travels → Create.
  Agency, Customer, Status pre-filled in italics.
- Payoff: "Nothing in this app knows about AI. The model did."
- Fallback: slide 23 (screenshot);
  `curl -s -u alice: 'http://localhost:4004/odata/v4/travel/$metadata' | grep -c SAP_Recommendations` → 6
- Slide 21 (first start) is a slide, not a demo: without the `db.impl` line the
  start blocks on a Hugging Face download. Do not run it.

## Demo 2 — slide 29 · branch 02

```bash
curl -s -u alice: -X POST 'http://localhost:4004/odata/v4/travel/Travels(ID=4,IsActiveEntity=true)/TravelService.draftEdit' -H 'Content-Type: application/json' -d '{}'
curl -s -u alice: 'http://localhost:4004/odata/v4/travel/Travels(ID=4,IsActiveEntity=false)?$expand=SAP_Recommendations' | jq .SAP_Recommendations
```

Then the terminal: the `payload to SAP AI Core` block. `Customer_ID` is in
"columns per row". Payoff: "Not a target. In every row." Fallback: slide 30.

## Demo 3 — slide 37 · branch 04

```bash
curl -s -u alice: 'http://localhost:4004/odata/v4/travel-assistant/summarize(travelID=1)' | jq     # mocked: true
# Ctrl-C, then
CDS_ENV=hybrid cds serve        # same curl → 502 from the real SDK
```

Payoff: "Same code, one profile apart." Fallback: slide 38.

## Demo 4 — slide 44 · branch 06

```bash
./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | jq -r '.result.tools[].name'   # describe, query
curl -s -o /dev/null -w '%{http_code}\n' -u alice: http://localhost:4004/mcp/travel                       # 405
```

Fallback: slide 45. Inspector (optional, needs network):
`npx @modelcontextprotocol/inspector --server-url http://localhost:4004/mcp/travel --transport http --header "Authorization: Basic YWxpY2U6"`

## Demo 5 — slide 47 · branch 07

```bash
./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"query","arguments":{"entity":"Travels","select":[{"ref":["ID"]}],"limit":5}}}'
./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | jq '.result.tools[] | select(.name=="query") | .inputSchema'
./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"query","arguments":{"cql":"SELECT from Travels { ID, Description, Agency.Name as Agency } where Agency.City = '"'"'Vienna'"'"' limit 3"}}}'
```

Payoff: "The schema is the truth." Fallback: slide 48.
If someone asks for CQN mode: `CDS_MCP_FORMAT=cqn cds watch` and the first call works.

## Demo 6 — slide 53 · branch 09

```bash
for u in alice agent viewer; do MCP_USER=$u ./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | jq -c '[.result.tools[].name]'; done
MCP_USER=nobody ./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'     # 403 (empty body)
./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"query","arguments":{"cql":"SELECT from Customers { ID, Email } limit 2"}}}'   # the leak
curl -s -u alice: 'http://localhost:4004/odata/v4/travel/Customers?$select=ID,Email&$top=1'                 # OData refuses
MCP_URL=http://localhost:4004/mcp/travel-agent ./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"describe","arguments":{}}}'
```

Payoff: "Hidden is not denied." Fallback: slides 54–56.

## Demo 7 — slide 58 · branch 10

```bash
jq -c '.mcpServers | keys' ~/.claude.json
CDS_MCP_AUTOWIRE=true cds watch          # instead of editing package.json
jq -c '.mcpServers | keys' ~/.claude.json   # + cds:TravelService, cds:TravelAgentService
claude -p "list all open travels with their agency and total price"
# Ctrl-C → entries gone.  Then restore:
cp ~/.claude.json.backup ~/.claude.json
```

Payoff: "Zero configuration — and it edited my home directory to get there."
Fallback: slides 59–60. VS Code (slide 60) is a screenshot; do not switch apps.

## Demo 8 — slide 63 · branch 12

```bash
./a2a-send.sh "list three travels with their agency" | jq -r '.result.status.message.parts[0].text'
# then the server log: [agents] request → [mcp] query SELECT * FROM Travels LIMIT 3 → completed
./a2a-send.sh "$(printf 'x%.0s' $(seq 1 300))"      # -32029 quota, before any model call
A2A_USER=nobody ./a2a-send.sh "hi"                   # -32003 Forbidden
```

Optional: http://localhost:4004/a2a/travel-agent/preview/ (Alpha chat UI) and
the **Agents** section on http://localhost:4004. Payoff: "The service we
curated for other people's agents is now an agent itself — and it runs as the
caller." Fallback: slide 64.

Do **not** switch to `llm: auto` on stage unless you want to show that it reads
`~/.claude/settings.json`; it resolves to a real Anthropic endpoint on this
machine and a message would call it.

## Known traps

- **Port 4004.** `cds serve` exits with `EADDRINUSE` while the old process keeps
  answering — with old code. Kill before every checkout. On 2026-11-06 a
  `cds watch` from the `academytailor-cap` worktree was still holding 4004.
- **`npm ci` on branch 12** pulls LangChain, LangGraph and `@cap-js/attachments`;
  on conference Wi-Fi that is minutes. Pre-install.
- **`@cap-js/ai` first start.** Any branch ≥ 01 without the `db.impl` line tries
  to download a model. The repo has the line; don't remove it to "show" it.
- **`~/.claude.json`.** Demo 7 writes to it. Back up, restore afterwards.
- **Inspector** needs Node `^22.23.4`; `mcp-rpc.sh` needs only curl and sed.
- **Fiori preview** needs network for UI5 from the CDN. If the venue is offline,
  Demo 1 falls back to the `$metadata` grep and slide 23.
