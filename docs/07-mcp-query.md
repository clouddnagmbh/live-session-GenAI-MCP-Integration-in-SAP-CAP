# 07 — `describe` and `query`: CQL, CQN, TOON and limits

**Adds:** row-limit annotations. Everything else here is exercising what branch
`06` already installed.

**Needs SAP AI Core:** no.

## The headline: the exercise's `query` example cannot work

Exercise 09 step 6 says to set `entity`, `select`, `where` and `limit`. Run it
verbatim against `@cap-js/mcp` 1.4.3 with default config:

```json
{"entity":"Travels","select":[{"ref":["ID"]}],"limit":5}
```
```
Input validation error: Invalid arguments for tool query:
  cql: Invalid input: expected string, received undefined
```

Because since **1.4.0** the default is `cds.mcp.format: "cql"`, and the live
input schema is exactly one property:

```json
{ "properties": { "cql": { "type": "string", "description": "CAP CQL statement …" } },
  "required": ["cql"] }
```

The capire page documents the *other* mode's parameters as if they were the
default. Read the live schema, not the docs:

```bash
./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
  | jq '.result.tools[] | select(.name=="query") | .inputSchema'
```

**This side-by-side is the best "docs drift is real" moment in the session.**

## CQL mode (the default) — and why it is the better demo

CQL is a superset of SQL, and it is genuinely nicer for an LLM to emit than CQN.

```bash
# path expressions instead of JOINs
{"cql":"SELECT from Travels { ID, Description, Agency.Name as Agency } where Agency.City = 'Vienna' limit 3"}
```
```
count: 5
data[3]{ID,Description,Agency,IsActiveEntity}:
  26,Wine tour to Vienna,Wiener Reisen,true
  234,Family holiday to Vienna,Wiener Reisen,true
  241,Ski trip to Vienna,Wiener Reisen,true
```

```bash
# postfix projection with a nested expand
{"cql":"SELECT from Travels { ID, Description, Bookings { Pos, FlightNo, Price } } limit 2"}

# aggregates — "which agencies have the most bookings?"
{"cql":"SELECT from Bookings { Travel.Agency.Name as Agency, count(*) as bookings } group by Travel.Agency.Name order by bookings desc limit 5"}
```
```
data[5]{Agency,bookings,IsActiveEntity}:
  Sol y Playa,92
  Provence Voyages,70
  Highland Routes,65
```

Not supported: anything but `SELECT`, and the database functions
`CURRENT_USER`, `SESSION_USER`, `SYSUUID`, `CURRENT_SCHEMA`.

## CQN mode — and how to make the exercise's example work

```json
{ "cds": { "mcp": { "format": "cqn" } } }
```

The schema changes to what capire documents:

```
["distinct","entity","groupBy","having","limit","offset","one","orderBy","search","select","where"]
```

and the exercise's payload now succeeds. Note the inverse is then also true —
a `cql` string is **rejected** in cqn mode, and `entity` becomes a closed enum
of exposed entity names.

### Undocumented difference: `count` means different things

| mode | `count` in the response |
|---|---|
| `cql` | the **unlimited total** (`$count` is forced true) — 168 for 168 open travels, while `data[3]` |
| `cqn` | the **page size** — 3 |

Verified with the same logical query in both modes. So **never** have an agent
compute `data.length === count` — the answer depends on a config flag. This is
in neither the plugin README nor capire.

## `describe`

```bash
./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"describe","arguments":{"entities":["Travels"]}}}'
```

The parameter is **`entities`, a plural array** — here the exercise is *more*
correct than capire, which documents a singular `entity`.

`describe` also tells the agent its own limits, which is genuinely useful:

```
    queryLimits:
      default: 20
      max: 50
```

## Row limits

Standard CAP annotations; the adapter honours them.

```cds
annotate TravelService with @cds.query.limit: { default: 20, max: 50 };
annotate TravelService.Bookings with @cds.query.limit: { default: 5, max: 10 };
```

Verified behaviour:

| request | result |
|---|---|
| `limit 500` on Travels (max 50) | `data[50]` — **silently clamped, no warning** |
| no limit on Travels | `data[20]` — service default |
| `limit 100` on Bookings (entity max 10) | `data[10]` — entity annotation overrides the service |
| no annotations anywhere | `default: null`, `max: 1000` — a **hardcoded** fallback |

An unbounded `SELECT` against an unannotated service will therefore hand an
agent up to **1000 rows**. Annotate your limits.

## TOON output

Results are TOON-encoded — a compact tabular form: one header line naming the
fields, then bare comma-separated rows. It costs far fewer tokens than JSON for
uniform result sets, which is the whole point when the consumer is an LLM.

> [!IMPORTANT]
> **There is no way to get JSON text output.** `cds.mcp.toon_format` was
> **removed in 1.4.2** ("toon is now always the output format"), so the
> exercise's `cds.mcp.toon_format: false` is dead config that does nothing.
> `cds.mcp.toonFormat` exists only in **CAP Java**.
>
> JSON is still available — as `structuredContent` alongside `content[0].text`.
> Whether you see it depends on your MCP client.

Also note `@toon-format/toon` is a **floating major** dependency (`>=2.3`, and
npm resolves 4.1.1 today), so recorded output can drift. Commit your lockfile.

## Two gotchas that will bite an agent

**Draft artifacts leak into every projection.** `IsActiveEntity` appears in
results even when you did not select it, because `Travels` is draft-enabled.
Branch `09`'s tailored projection is the fix.

**Key associations collide with path expressions:**

```
{"cql":"SELECT from Bookings { Travel.ID, Pos } limit 100"}
-> Error executing CQL: Duplicate definition of element "Travel_ID"
```

`Travel` is a key association, so `Travel_ID` is already implicitly in the
projection. Alias it (`Travel.ID as TravelID`) or leave it out.
