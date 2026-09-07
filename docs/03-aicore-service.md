# 03 — SAP AI Core as a CAP service

**Adds:** `srv/ai-core-demo.cds` / `.js` — calling SAP-RPT-1 directly instead of
implicitly through the Fiori recommendations UI, plus the AI Core admin API.

**Needs SAP AI Core:** `predictTravel` **no** (mock-backed). `listResourceGroups`
**yes** — and read the warning below before you demo it.

## `predictTravel` — a hand-crafted RPT-1 call, runs locally

```bash
curl -s -u alice: -X POST http://localhost:4004/odata/v4/aicore-demo/predictTravel \
  -H 'Content-Type: application/json' \
  -d '{"description":"Ski trip to Innsbruck","contextRows":200}'
```

```json
{ "contextRowsSent": 201,
  "predictions": [ {"column":"Agency_ID","value":"5"},
                   {"column":"Currency_code","value":"EUR"},
                   {"column":"Status_code","value":"O"} ] }
```

This is the whole RPT-1 contract in one call, and it shows what makes the model
unusual: **there is no training step.** You send context rows plus one row with
holes in it, and the model fills the holes by in-context learning.

Two things you must get right, neither of which is obvious:

1. **Targets are marked with the literal string `'[PREDICT]'`**, not `null`.
   The sentinel is set in `AICoreService.js:185`. Passing `null` silently
   returns `predictions: []` — no error, no warning.
2. The action signature is `fetchPredictions({ rows, entity, predictionColumns })`
   (`srv/AICoreService.cds:216`), and `entity` must be a **CDS entity name** that
   exists in the model — it is used to derive the Python dtype schema.

Note the endpoint is `/odata/v4/aicore-demo`, not `/ai-core-demo`: CAP slugifies
`AICoreDemo`. The same rule sets the MCP endpoint path in branch `06`.

## `listResourceGroups` — the Calesi part, and a real hazard

The pitch is that AI Core admin objects are just a CAP service you query with CQL:

```js
const aiCore = await cds.connect.to('AICore')
const { resourceGroups } = aiCore.entities
await aiCore.run(SELECT.from(resourceGroups))
```

> [!WARNING]
> **`MockAICoreService` does not mock this.** It extends `AICoreService` and
> overrides only `_predictRowColumns`; `resourceGroups`, `deployments` and
> `configurations` keep their real HTTP handlers. With no binding,
> `AICoreService._getToken()` (`AICoreService.js:127`) throws
> `Cannot read properties of undefined (reading 'url')` — and CAP treats it as
> an uncaught error that **terminates the server process**. Not a 500. The
> process exits and your demo is over.

That is why the handler in this branch wraps the call:

```js
try   { ... }
catch { req.reject(501, 'AI Core admin API needs a real service binding …') }
```

Verified: with the guard, you get a clean 501 and the server stays up.

```bash
curl -s -u alice: 'http://localhost:4004/odata/v4/aicore-demo/listResourceGroups()'
# {"error":{"code":"501","message":"AI Core admin API needs a real service binding. ..."}}
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:4004/    # 200 — still alive
```

**Worth reporting upstream to `cap-js/ai`.**

## The cloud path (documented, not run here)

```bash
cf login -a <your-cf-api-endpoint>
cf target

cds bind AICore -2 <your-ai-core-instance>   # pass the name; see below
cds watch --profile hybrid                    # WITHOUT this you silently keep the mock
```

| Form | Result |
|---|---|
| `cds bind AICore -2 <instance>` | **preferred** — binds under the plugin's own `cds.requires` key |
| `cds bind ai-core -2 <instance>` | also works (credentials match by VCAP label `aicore`) but writes a *duplicate* requires entry |
| `cds bind -2 <instance>` | **fails** — `unknown CDS service name for service … of kind AICore-btp` |

`cds.requires.AICore` defaults to `AICore-mocked`; only the `[production]` and
`[hybrid]` profiles map it to `AICore-btp`. There is **no log message** telling
you which one you got, so `cds watch` with a perfectly good binding still gives
you mock output.

### If you do have an entitlement, pre-warm the deployment

The first real prediction against a fresh resource group provisions an RPT-1
deployment and **blocks while polling** — `300ms · 2^i` for 10 attempts, roughly
five minutes. Create it ahead of the session:

```js
await aiCore.run(INSERT.into(configurations).entries({
  scenarioId: 'foundation-models',
  name: 'sap-rpt-1-small',
  executableId: 'aicore-sap',
  parameterBindings: [
    { key: 'modelName',    value: 'sap-rpt-1-small' },
    { key: 'modelVersion', value: 'latest' }
  ]
}))
await aiCore.run(INSERT.into(deployments).entries({ configurationId: configuration.id }))
```

Also note: the plugin finds an existing deployment by regex-matching the
**configuration name** against `/rpt-1/`, and hardcodes `sap-rpt-1-small` with
`modelVersion: 'latest'`. There is no way to select `sap-rpt-1-large`,
`sap-rpt-1-oss` or SAP-RPT-1.5.
