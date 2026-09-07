# GenAI & MCP Integration in SAP CAP

Companion repository for the live session **"GenAI & MCP Integration in SAP CAP"**.

`main` holds the base CAP application. **Every demo is its own branch**, and the
branches form a linear chain — each builds on the previous one, so
`git diff main..<branch>` shows exactly what that step added.

> All facts, versions and annotations in this repo were verified against plugin
> **source code and integration tests** on 2026-09-07 — not against READMEs.
> Where the official docs and the code disagree, the code wins and the branch
> README says so.

## The base app

A deliberately small travel domain: `Travels` (draft-enabled) with `Bookings`,
`TravelAgencies`, `Customers` and a `TravelStatus` code list.

```
300 travels · 752 bookings · 20 agencies · 60 customers
```

The seed data is **generated deterministically** and carries two learnable
patterns, so AI recommendations have something real to find:

| Pattern | Strength |
|---|---|
| an agency always bills in its country's currency | 100% (1 currency per agency) |
| customers rebook with their "home" agency | 78.7% |
| expensive travels get rejected more often | correlated with `TotalPrice` |

All three status codes are populated (168 Open / 100 Accepted / 32 Rejected), so
no filter demo returns an empty list. The database deploys with
`assert_integrity: "DB"`, which proves every foreign key resolves.

## Branches

Each branch carries its own `docs/<branch-name>.md` with the exact commands, the
`verify:` checks, and what the official docs get wrong.

### Track A — GenAI

| Branch | Demo | Runs offline? |
|---|---|---|
| `01-recommendations-mock` | SAP-RPT-1 field recommendations via `@cap-js/ai` — one `npm add`, zero handler code | yes (mock) |
| `02-recommendations-control` | `@UI.RecommendationState`, and proof it is **not** a privacy control | yes (mock) |
| `03-aicore-service` | `AICore` as a CAP service; a hand-crafted RPT-1 call | yes (predictions) |
| `04-genai-orchestration` | a **real generative call** via SAP Cloud SDK for AI, behind a mockable CAP service | yes (local impl) |
| `05-vector-rag` | `cds.Vector` + similarity search + a full RAG chain | yes |

### Track B — MCP

| Branch | Demo | Runs offline? |
|---|---|---|
| `06-mcp-basics` | expose the service via `@mcp`; explore it with `mcp-rpc.sh` | yes |
| `07-mcp-query` | `describe` / `query` in CQL **and** CQN, TOON, row limits | yes |
| `08-mcp-actions` | writes via unbound actions, the `call` tool | yes |
| `09-mcp-security` | `@requires` / `@restrict` / `@cds.api.ignore`, tailored projections | yes |
| `10-agent-clients` | autowiring into Claude Code; manual VS Code / Copilot config | yes |
| `11-genai-mcp-together` | one service, two consumers — an agent invoking CAP's own RAG | yes |

**No BTP entitlement is required for any demo.** Every branch runs offline; the
cloud paths are documented and, where possible, wired so that switching to them
is a profile change rather than a code change.

## What the upstream exercises get wrong

This repo started as a verification of SAP's `recap2026` exercises 08 and 09.
The corrections are load-bearing, not cosmetic:

| Claim | Reality |
|---|---|
| MCP tools are `describe`, `query`, `call_action` | `call_action` was renamed **`call`** in `@cap-js/mcp` 1.3.0 and appears nowhere in shipped code. And `call` only exists once the service has an unbound action |
| `query` takes `entity` / `select` / `where` / `limit` | Default is `format: "cql"` — one `cql` string, `additionalProperties: false`. The exercise's payload fails Zod validation |
| `cds.mcp.toon_format: false` gives JSON | Removed in 1.4.2. TOON is unconditional; JSON only via `structuredContent` |
| MCP Inspector: "Transport Type" → "Via Proxy" → "Connect" | That is the v1 UI. `npx` gives 2.5.0, needs Node ≥ 22.19.0, and `--transport http` is mandatory |
| `@UI.RecommendationState: 0` keeps a field out of the payload | It is dropped as a prediction *target* but **still sent** to SAP AI Core |
| "You should see a message indicating that the AI plugin is active" | The plugin logs nothing — not on startup, not on mock fallback |
| `claude "prompt"` | Opens an interactive session and never exits. Use `claude -p` |
| `annotate … with @odata @hcql @mcp` | `@cap-js/hcql` does not exist on npm; HCQL ships inside `@sap/cds` |

Two problems are ours to report upstream, found by building this repo:

- **`@cds.api.ignore` on an element is not access control** in MCP's default
  `cql` mode — hidden from `describe`, still returned by `query`, while OData and
  `cqn` mode both refuse it. See `docs/09-mcp-security.md`.
- **Querying AI Core admin entities with no binding terminates the CAP
  process** — an uncaught `TypeError` in `AICoreService._getToken()`, not a 500.
  See `docs/03-aicore-service.md`.

## Quick start

```bash
npm ci
npm run watch
```

Then open:

| What | URL |
|---|---|
| Service index | http://localhost:4004 |
| Fiori preview (list report) | http://localhost:4004/$fiori-preview/TravelService/Travels |
| OData | http://localhost:4004/odata/v4/travel/Travels |
| MCP (full service) | `POST http://localhost:4004/mcp/travel` (from branch `06`) |
| MCP (curated agent surface) | `POST http://localhost:4004/mcp/travel-agent` (from branch `09`) |

Local auth uses CAP's mocked users — `alice` (role `admin`) with an empty
password, i.e. `Authorization: Basic YWxpY2U6`.

No UI5 application is generated: CAP 10's built-in `$fiori-preview` serves a
full Fiori elements list report and object page straight from the annotations
in `app/`. That keeps the UI out of the branch diffs entirely.

## Prerequisites

```
node                >= 22.19.0    (MCP Inspector v2 needs this; @sap/cds 10 needs >= 22)
@sap/cds             10.0.6       pinned
@cap-js/sqlite       3.0.2        pinned
@sap/cds-dk          10.x         global (npm i -g @sap/cds-dk)
```

Versions are **pinned exactly**, not floated. Between `@cap-js/mcp` 1.2.0 and
1.4.3 — about six weeks — a tool was renamed, the default query input format
changed, and a config flag was deleted. Floating those ranges breaks demos.

## Layout

```
db/schema.cds        domain model
db/data/*.csv        deterministic seed data (generated, committed)
srv/travel-service.cds   the service
app/annotations.cds  draft + value helps  <- gates the AI recommendations feature
app/fiori.cds        Fiori elements UI annotations
docs/<branch>.md     one per branch: commands, verify checks, doc corrections
mcp-rpc.sh           minimal MCP client (branch 06+) -- no Inspector needed
```

## Verifying MCP without the Inspector

`mcp-rpc.sh` posts one JSON-RPC call and unwraps the SSE frame. No download, no
Node version floor, fully deterministic — the safest thing to run on stage:

```bash
./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | jq -r '.result.tools[].name'

MCP_USER=viewer ./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
MCP_URL=http://localhost:4004/mcp/travel-agent ./mcp-rpc.sh '…'
```
