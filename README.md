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

| Branch | Demo | Needs SAP AI Core? |
|---|---|---|
| `main` | base app | no |
| `01-recommendations-mock` | RPT-1 field recommendations via `@cap-js/ai` | no (mock) |
| `02-recommendations-control` | `@UI.RecommendationState` — and what *really* leaves the system | no (mock) |
| `03-aicore-service` | `AICore` as a CAP service (Calesi pattern) | code only |
| `04-genai-orchestration` | a real generative LLM call via SAP Cloud SDK for AI | code + local mock |
| `05-vector-rag` | `cds.Vector` + similarity search | no |
| `06-mcp-basics` | expose the service via `@mcp`, explore with MCP Inspector | no |
| `07-mcp-query` | `describe` / `query` in CQL **and** CQN, TOON, row limits | no |
| `08-mcp-actions` | writes via unbound actions, the `call` tool | no |
| `09-mcp-security` | `@requires` / `@restrict` / `@cds.api.ignore`, tailored projections | no |
| `10-agent-clients` | autowiring into Claude Code; manual VS Code config | no |
| `11-genai-mcp-together` | one service, two consumers | no |

**No BTP entitlement is required for any demo.** Branches that can use real SAP
AI Core say so and ship a local path that works without it.

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
```
