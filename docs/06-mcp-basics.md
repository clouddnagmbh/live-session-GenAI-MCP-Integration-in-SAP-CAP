# 06 — Expose the service over MCP

**Adds:** `@cap-js/mcp@1.4.3`, `srv/travel-mcp.cds` (one annotate statement), and
`mcp-rpc.sh` — a 6-line MCP client for deterministic verification.

**Needs SAP AI Core:** no. No LLM required at all for this branch.

## The whole change

```cds
using { TravelService } from './travel-service';

annotate TravelService with @odata @mcp
  @mcp.instructions: 'This service manages travel bookings. Use `describe` to explore …';
```

```
[cds] - serving TravelService {
  at: [ '/odata/v4/travel', '/mcp/travel' ],
}
```

That is the entire integration. No handler, no schema, no tool definitions.

### `@odata` is not optional

Any protocol annotation **replaces** the default protocol set. `annotate
TravelService with @mcp;` alone leaves only `/mcp/travel` — the Fiori preview and
every OData call in this repo break. Verified in the runtime's `endpoints4()`.

The endpoint path is the **slugified service name**: `TravelService` →
`/mcp/travel`. Override with `@mcp: 'travels'`. (Same rule gave branch 03
`/odata/v4/aicore-demo` from `AICoreDemo`.)

## Verify — deterministically, no Inspector needed

`./mcp-rpc.sh` posts one JSON-RPC call and unwraps the SSE frame. It has no Node
version floor and nothing to download, which makes it the safest thing to use on
stage:

```bash
./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  | jq -r '.result.tools[].name'
```

```
describe
query
```

> [!IMPORTANT]
> **Two tools, not three.** The exercise this is based on says you will see
> `describe`, `query` and `call_action`. Both halves are wrong:
>
> 1. **`call_action` does not exist.** It was renamed to **`call`** in
>    `@cap-js/mcp` 1.3.0. Verified in the installed 1.4.3: `lib/tools/call.js:19`
>    builds `prefix + 'call'`, and `call_action` appears **nowhere** in the
>    shipped code. The *live* capire page still documents `call_action` — it is
>    stale; `cap-js/docs@main` already says `call`.
> 2. **`call` is only registered when the service has unbound actions or
>    functions.** `TravelService` has none yet, so you get two tools. Branch `08`
>    adds one and the third tool appears.

### `GET` returns 405 — by design

```bash
curl -s -o /dev/null -w '%{http_code}\n' -u alice: http://localhost:4004/mcp/travel   # 405
```

The transport is stateless Streamable HTTP, POST only. Anyone who "tests" the
endpoint in a browser will conclude it is broken. Say this before they try.

Auth is CAP's own mocked strategy: `alice`, empty password, i.e.
`Authorization: Basic YWxpY2U6` (`printf 'alice:' | base64`).

## Your doc comments are the agent's documentation

The plugin ships `cds.cdsc.docs: true`, so **CDS doc comments become the
model description an LLM reads**:

```
service: TravelService
description: "Manages travel bookings: which customer travels where, through which agency, …"
entities[9:]{description}:
  Travels: "A travel booked by a customer through an agency.\nIts status follows Open -> Accepted | Rejected."
  TravelStatus: Status code list for travels. …
  Customers: A customer who books travels.
```

This is the cheapest quality win in the whole session: `/** … */` on your
entities directly improves agent behaviour.

> [!WARNING]
> A doc comment on an **`extend`** block *replaces* the target entity's
> description. This bit me: a `/** … */` describing the added elements on an
> `extend our.TravelAgencies` block made agents believe that text *was* the
> definition of `TravelAgencies`. Use `//` on `extend` blocks.

## Two plugins, one unintended interaction

`describe` also shows the agent this:

```
  Bookings_Recommendations: Entity Bookings_Recommendations
  Travels_Recommendations: Entity Travels_Recommendations
```

Those are the synthetic companion entities `@cap-js/ai` injected in branch `01`.
They are meaningless to an LLM and they cost tokens on every `describe`.

Nobody asked for this — it is what you get when two plugins annotate the same
service. Branch `09` fixes it properly, with a tailored MCP projection instead of
annotating the full service. Worth showing: **`@mcp` on a service exposes
whatever is in that service, including things other plugins put there.**

## Autowiring is off in this branch

The plugin defaults `cds.mcp.autowire: true`, which **writes to your
`~/.claude.json`** on every `cds watch`. Branches 06–09 are driven by
`mcp-rpc.sh` and the Inspector, so they set:

```json
{ "cds": { "mcp": { "autowire": false } } }
```

Verified: with this set, `cds watch` leaves `~/.claude.json` untouched. Branch
`10` turns it back on and makes it the demo.

## If you want the MCP Inspector UI

```bash
unset MCP_CATALOG_PATH
npx @modelcontextprotocol/inspector \
  --server-url http://localhost:4004/mcp/travel \
  --transport http \
  --header "Authorization: Basic YWxpY2U6"   # use: printf 'alice:' | base64
```

Three things the exercise gets wrong here, all verified:

- `npx @modelcontextprotocol/inspector` now resolves to **2.5.0**, a full
  rewrite. The v1 click-path it describes — "Transport Type", "Via Proxy", a
  "Connect" button — **does not exist**. The proxy process was deleted; you
  connect with a toggle switch and headers live under Server Settings.
- Inspector v2 requires **Node ≥ 22.19.0**. `npm` only warns (`EBADENGINE`) and
  then fails later with an unrelated-looking error.
- **`--transport http` is mandatory.** `/mcp/travel` does not end in `/mcp`, and
  v2 refuses to guess: *"Transport type not specified and could not be determined
  from URL"*. v1 silently fell back to SSE.

If you cannot upgrade Node, pin the version whose UI matches the exercise text:

```bash
npx @modelcontextprotocol/inspector@v1-latest --transport http \
  --server-url http://localhost:4004/mcp/travel
```
