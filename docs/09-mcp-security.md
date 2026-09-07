# 09 — Authorization, hiding data, and designing the agent's surface

**Adds:** domain roles and mock users, CAP authorization on `TravelService`,
`@cds.api.ignore` examples, and `TravelAgentService` — a tailored MCP-only
projection.

**Needs SAP AI Core:** no.

## Authorization is just CAP authorization

No MCP-specific concepts. `@requires` and `@restrict`, and the adapter
recomputes the tool list and the entity/action **enums per request** from the
caller's roles.

```cds
annotate TravelService with @(requires: ['travel-admin','travel-agent','travel-viewer']);

annotate TravelService.Travels with @(restrict: [
  { grant: 'READ',  to: ['travel-admin','travel-agent','travel-viewer'] },
  { grant: 'WRITE', to: ['travel-admin'] }
]);
annotate TravelService.Customers with @(restrict: [
  { grant: 'READ', to: ['travel-admin','travel-agent'] }   // personal data
]);
annotate TravelService.acceptTravelById with @(requires: 'travel-admin');
```

Mock users in `package.json`: `alice` (travel-admin), `agent` (travel-agent),
`viewer` (travel-viewer), `nobody` (no roles).

### Verified: every user gets a different server

```bash
MCP_USER=viewer ./mcp-rpc.sh '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```

| user | `describe` entity enum | `call` action enum |
|---|---|---|
| `alice` (admin) | Travels, Customers, Bookings, … | `acceptTravelById`, `revenueByAgency` |
| `agent` | Travels, Customers, Bookings, … | `revenueByAgency` only |
| `viewer` | **no `Customers`** | `revenueByAgency` only |
| `nobody` | — | — |

And it is enforced, not merely hidden:

| attempt | result |
|---|---|
| anonymous (no header) | **HTTP 401** |
| `nobody` (authenticated, no roles) | **HTTP 403** |
| `viewer` queries `Customers` anyway | `Entity 'Customers' cannot be resolved for service TravelService` |
| `agent` calls `acceptTravelById` anyway | `Invalid arguments for tool call: action: Invalid input: expected "revenueByAgency"` |

The last one is elegant: the *enum itself* is the guard, so the model gets a
schema violation rather than a permission error, and self-corrects.

> [!NOTE]
> We have a **service-level** `@requires`, so an unauthorized caller gets a
> clean 401/403. Without one, the plugin's own tests show an authenticated user
> with no entity grants receives `tools: []` and **no error** — a server that
> looks broken rather than restricted. Always put `@requires` on the service.

## `@cds.api.ignore` — and a real leak in the default config

There is no `@mcp.ignore`. The tool is `@cds.api.ignore`:

```cds
annotate TravelService.Customers with { Email @cds.api.ignore };
annotate TravelService.revenueByAgency with @cds.api.ignore;
```

On an **action** it works completely — `revenueByAgency` disappears from the
`call` enum. On an **element** it hides `Email` from `describe`:

```
Customers elements: ID, FirstName, LastName        <- no Email
```

> [!CAUTION]
> **In the default `format: "cql"` mode, the ignored element is still fully
> readable.** Verified on this branch:
>
> | access path | `SELECT ID, Email FROM Customers` |
> |---|---|
> | OData | rejected — *"Property Email does not exist in TravelService.Customers"* |
> | MCP `format: "cqn"` | rejected — *"Invalid select field(s): Email"* |
> | **MCP `format: "cql"` (the default)** | **returns real email addresses** |
>
> The cause is in `lib/tools/query.js`: `validateFields()` — which rejects
> ignored elements — is called only on the **CQN** branch. The CQL branch
> validates entity references, the function allowlist and expand targets, but
> **not columns**.
>
> So `@cds.api.ignore` on an element is **discovery-hiding, not access control**,
> under the shipped default. An agent that guesses the name, or reads it from
> the OData `$metadata`, or sees it in an error message, gets the data.
>
> **Report upstream. Until fixed, do not rely on element-level
> `@cds.api.ignore` to protect anything.**

The reliable control is the one below.

## Design the agent's surface deliberately

Branch `06` annotated the whole `TravelService`, and the agent saw things nobody
meant to publish:

- `Travels_Recommendations` and `Bookings_Recommendations` — synthetic entities
  `@cap-js/ai` injected in branch `01`
- `IsActiveEntity` in every projection, because `Travels` is draft-enabled
- every managed field: `createdAt`, `createdBy`, `modifiedAt`, `modifiedBy`

`srv/travel-agent-service.cds` is the fix, and it is what capire recommends:

```cds
/**
 * Read-only travel reporting surface, designed for AI agents.
 * Every entity and element here was chosen deliberately.
 */
@mcp
@mcp.instructions: 'Read-only travel booking data for reporting. Status codes: O=Open, A=Accepted, X=Rejected. …'
@(requires: ['travel-admin','travel-agent','travel-viewer'])
service TravelAgentService {
  /** A booked travel: who is going where, through which agency, at what price. */
  @readonly entity Travels as projection on our.Travels {
    ID, Description, BeginDate, EndDate, TotalPrice,
    Currency.code as Currency, Status.name as Status,
    Agency.Name as Agency, Agency.City as AgencyCity
  }
  /** A travel agency and the city it operates from. */
  @readonly entity Agencies as projection on our.TravelAgencies { ID, Name, City }
}
annotate TravelAgentService with @cds.query.limit: { default: 20, max: 100 };
```

Served at `/mcp/travel-agent`. Note there is **no `@odata`** here — this service
is MCP-only, which is exactly what a bare `@mcp` gives you.

Result: two entities, eight elements, flat readable values.

```
service: TravelAgentService
description: "Read-only travel reporting surface, designed for AI agents. …"
entities[2:]{description}:
  Travels: "A booked travel: who is going where, through which agency, at what price."
  Agencies: A travel agency and the city it operates from.
```
```
data[3]{ID,Description,Agency,Status,TotalPrice}:
  1,Wellness retreat to Munich,Bayern Tours,Open,"1643.0000"
```

### One subtlety worth the slide

Project on the **domain** entities (`our.Travels`), not the service ones. A
projection on a draft-enabled service entity **still carries `IsActiveEntity`**
into every result — I hit exactly that, and switching the projection source
removed it.

Fewer, better-named, well-documented elements also mean fewer tokens per
`describe` and materially better agent behaviour. Curating the surface is a
quality decision as much as a security one.

## Production reality — put this on a slide

Everything above is CAP doing its job. What CAP and this adapter do **not** give
you:

- **`@cap-js/mcp` is Beta**, and capire states the tools are "not a stable API".
  Pin the version.
- capire is explicit that this is **not an SAP-endorsed architecture** "for
  purposes of section 2.2.2 of the **SAP API Policy**", is intended for **custom
  CAP application services only**, and must not be used to proxy SAP
  Application APIs.
- **No governance controls at all**: no rate limiting, no agent audit logging, no
  approval workflow, no policy enforcement, and **no prompt-injection
  protection**. Note that any free-text field an agent reads — our
  `Description`, our agency names and cities — is untrusted input to whatever model
  consumes it.
- **No MCP OAuth.** The adapter never sends `WWW-Authenticate` and serves no
  `/.well-known/oauth-protected-resource`, so a spec-compliant client cannot
  self-authenticate. You hand it a static header locally, and a pre-obtained
  Bearer JWT in production (XSUAA/IAS via CAP's normal auth).
- capire's own advice is to front it with the **MCP Gateway of SAP Integration
  Suite**, or **SAP Agent Gateway** — which is not GA.
- If you route MCP through the standard approuter, note `xs-app.json` commonly
  sets `"csrfProtection": true`, and MCP is POST-only. Expect rejections without
  an `x-csrf-token`.
