# 11 — One service, two consumers

**Adds:** `recommendAgency` — a CAP-owned generative capability exposed as an
MCP-callable operation — and the MCP Server Card.

**Needs SAP AI Core:** no.

## The thesis

Every branch so far did one thing. This one puts them on the same service:

```
                    ┌──────────────────────────────┐
   human ──────────▶│  Fiori elements + RPT-1      │  branches 01–03
                    │  soft-fill recommendations   │
                    ├──────────────────────────────┤
                    │      TravelService           │
                    │  one model · one authz layer │
                    │  one set of business rules   │
                    ├──────────────────────────────┤
   agent ──────────▶│  MCP: describe/query/call    │  branches 06–10
                    └──────────────────────────────┘
                                  │
                                  ▼
                          LLM service (04)
```

The point is not that CAP can do AI. It is that **the semantics an LLM needs are
already in your CDS model** — entity and element names, doc comments,
associations, code lists, value helps, authorization, and business rules — and
both consumers get them from the same place.

## The convergence, made concrete

The interesting move is not "agent calls CAP". It is **agent calls a generative
capability that CAP owns**:

```cds
extend service TravelAgentService with {
  /**
   * Recommend a travel agency for a free-text wish.
   * Reads the agencies this caller is allowed to see, puts them in the prompt
   * and asks the LLM to choose one. The prompt is built by CAP, not by the
   * agent, so the caller never decides what the model gets to see.
   */
  function recommendAgency(wish : String) returns { … };
}
```

```bash
MCP_URL=http://localhost:4004/mcp/travel-agent ./mcp-rpc.sh '{"jsonrpc":"2.0","id":9,
  "method":"tools/call","params":{"name":"call","arguments":
  {"action":"recommendAgency","parameters":{"wish":"a quiet wellness week near a lake"}}}}'
```

```
action: recommendAgency
kind: function
result:
  wish: a quiet wellness week near a lake
  answer: "For \"a quiet wellness week near a lake\" I would suggest Alpine Escapes
           (Innsbruck). [mock answer — no language model was called]"
  model: mock
  mocked: true
```

> [!NOTE]
> The offline mock always picks the **first** agency in the list — it is not
> reasoning about the wish. That is the point: it proves the wiring, the tool
> contract and the authorization, and nothing more. Switch to `--profile hybrid`
> and a real model chooses.

The agent did **not** generate the recommendation. CAP did — with our data, our
projection, our authorization, and our chosen prompt. The agent called one tool.

That matters because it moves the interesting decisions inside your governed
boundary:

| decision | who makes it |
|---|---|
| which rows the model may see at all | your CDS projection + `@restrict` |
| what goes into the prompt | your handler |
| which model, which region | your `cds.requires` profile (branch 04) |
| what the caller gets back | your return type |
| who may ask at all | `@requires` on the operation (branch 09) |

Note what the handler reads: `this.read('Agencies')`, through the curated
projection from branch 09, as **this** caller. A `travel-viewer` and a
`travel-admin` do not get the same prompt, and neither of them can widen it.

## The MCP Server Card

The plugin registers a compile target that emits a machine-readable description
of the server:

```bash
cds compile db srv app -2 mcp -s TravelAgentService
cds compile db srv app -2 mcp -s all      # one card per service
```

```json
{
  "name": "sap.cds.services/travel-agent",
  "supportedProtocolVersions": ["2025-11-25"],
  "remotes": [{ "type": "streamable-http", "url": "/mcp/travel-agent" }],
  "tools": [
    { "name": "query",    "annotations": { "readOnlyHint": true,  "idempotentHint": true } },
    { "name": "describe", "annotations": { "readOnlyHint": true } },
    { "name": "call",     "annotations": { "readOnlyHint": false, "destructiveHint": true } }
  ]
}
```

Two things worth pointing out:

- The tool annotations are honest: `call` is flagged `destructiveHint: true`, so a
  client can require confirmation before it runs. `query` and `describe` are
  `readOnlyHint: true`.
- The card confirms `"additionalProperties": false` on the `query` input schema —
  which is *why* the exercise's CQN parameters are rejected in the default mode
  (branch 07).

> [!NOTE]
> The card's `$schema` points at an **SAP-internal** host
> (`pages.github.tools.sap`), so you cannot resolve it from outside SAP's network.

## What is GA, what is not

| component | status |
|---|---|
| CAP protocol adapters, CDS, draft, authorization | GA |
| **SAP-RPT-1** on AI Core / Generative AI Hub | GA |
| SAP Cloud SDK for AI (`@sap-ai-sdk/*`) | GA |
| `@cap-js/ai` recommendations | plugin 1.1.0; `UI.Recommendations` is `Common.Experimental` in SAP's own vocabulary |
| **`@cap-js/mcp`** | **Beta**; capire says the tools are "not a stable API" |
| CAP **Java** MCP adapter | **not publicly released** — `com.sap.cds:cds-adapter-mcp` needs SAP-internal artifactory |
| SAP Agent Gateway | not GA |

## The honest closing slide

Three things this repo demonstrated that the documentation does not tell you:

1. **`@UI.RecommendationState: 0` is not a privacy control.** The field is
   dropped as a prediction target but still shipped to SAP AI Core in all 301
   context rows (branch 02).
2. **Element-level `@cds.api.ignore` is not access control** in MCP's default
   `cql` mode. `Email` is hidden from `describe` and returned by `query` — while
   OData and `cqn` mode both correctly refuse it (branch 09).
3. **`@cap-js/mcp` has no governance layer at all.** No rate limiting, no agent
   audit log, no approval workflow, no prompt-injection protection. Any free-text
   field an agent reads — our `Description`, our agency names — is untrusted
   input to whatever model consumes it. And the **SAP API Policy** still applies:
   capire is explicit that this is *not* an SAP-endorsed architecture for
   purposes of section 2.2.2, is for custom CAP services only, and must not
   proxy SAP Application APIs.

None of that makes the feature bad. It makes it a Beta feature that you deploy
behind a gateway, with a curated projection, and with your eyes open.
