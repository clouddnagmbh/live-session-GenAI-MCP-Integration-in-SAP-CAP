# 08 — Writing through MCP, and the `call` tool

**Adds:** two unbound operations and one bound one (for contrast), plus the
`per_action_tool` / `prefix` flags.

**Needs SAP AI Core:** no.

## MCP cannot write. Actions can.

The adapter supports `READ` plus **unbound** actions and functions. No CREATE,
no UPDATE, no DELETE; non-`SELECT` CQL is rejected outright.

That is not the limitation it first looks like — it is the governance story. An
agent cannot `UPDATE Travels SET Status='A'`. It has to call an operation you
wrote, which means your validation, your authorization and your state machine
all still apply.

```cds
/** Accept a travel, moving its status from Open to Accepted. */
action acceptTravelById(travel : Integer, note : String) returns { … };

/** Total revenue per agency over a date range. */
function revenueByAgency(from : Date, to : Date) returns array of { … };
```

## The third tool finally appears

```
describe
query
call
```

Branch `06` showed only two tools. `call` is registered **only when the service
has unbound actions or functions** — which is the second reason the exercise's
"you should see three tools" was wrong (the first being that it calls the tool
`call_action`, a name removed in 1.3.0).

Its schema closes the action name to an enum of exactly what is exposed:

```json
{ "action": { "type": "string", "enum": ["acceptTravelById", "revenueByAgency"] },
  "parameters": { "type": "object" } }
```

## Bound actions are invisible to MCP

`srv/travel-actions.cds` also defines a **bound** action:

```cds
extend TravelService.Travels with actions {
  action rejectTravel() returns TravelService.Travels;
}
```

It does not appear in the `call` enum, and `describe` lists only two:

```
actions[2:]{kind,description}:
  acceptTravelById: action,"Accept a travel, moving its status from Open to Accepted. …"
  revenueByAgency: function,"Total revenue per agency over a date range. …"
```

The adapter collects service-namespace children only (`srv.actions`). Anything
bound to an entity is unreachable.

**This is the single most likely thing to derail a real MCP project.** Every
interesting operation in a typical CAP service is bound to an entity — the
upstream SAP sample is a perfect example: its four interesting travel actions
are all bound, so its `call` tool can only reach two `exportJSON`/`exportCSV`
functions. Plan an unbound facade.

## A write, end to end

```bash
# before
{"cql":"SELECT from Travels { ID, Status.code as st } where ID = 2"}   ->  2,O

# the write
{"action":"acceptTravelById","parameters":{"travel":2,"note":"approved by agent"}}
```
```
action: acceptTravelById
kind: action
result:
  ID: 2
  Status: A
  note: approved by agent
```
```bash
# after
{"cql":"SELECT from Travels { ID, Status.code as st } where ID = 2"}   ->  2,A
```

And call it a second time:

```
Error calling acceptTravelById: Travel 2 is not Open (status A)
```

**That error is the whole point.** The agent went through the service, hit the
`409` in the handler, and got a message it can reason about. Contrast with
letting an agent near the database.

## `per_action_tool: true`

```json
{ "cds": { "mcp": { "per_action_tool": true } } }
```
```
describe
query
acceptTravelById      <- one tool per operation, `call` is gone
revenueByAgency
```

Parameters are **flattened** onto the tool, which most models handle better than
a nested `parameters` object:

```json
{ "travel": { "type": "integer" }, "note": { "type": "string" } }
```

Trade-off: a large service becomes a large tool list, and tool lists cost
context on every request. Use it when you have a handful of high-value
operations.

## `prefix: true`

```json
{ "cds": { "mcp": { "prefix": true } } }
```
```
TravelService-describe
TravelService-query
TravelService-acceptTravelById
```

Needed when one client connects to several CAP MCP servers, which would
otherwise all expose bare `describe` / `query` / `call`. The prefix is the
**full service name** plus `-`, not the slugified path.

> [!WARNING]
> **Only the boolean `true` works.** `lib/utils/service-name.js` does
> `cds.env.mcp?.prefix === true`, so any string value collapses to no prefix at
> all. Verified: `"prefix": "{service.name}_"` produced bare
> `describe / query / call` — silently, no warning. The string-template branch
> is unreachable dead code.

> [!NOTE]
> Custom `@mcp.instructions` are **not** rewritten when prefixing. Our
> instructions still say "use `query`" while the tool is `TravelService-query`.
> Only the default instructions are prefix-aware. Keep tool names out of custom
> instruction text, or set them per prefix configuration.
