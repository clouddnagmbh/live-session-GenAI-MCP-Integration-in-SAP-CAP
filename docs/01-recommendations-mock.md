# 01 — RPT-1 field recommendations (mock)

**Adds:** `@cap-js/ai@1.1.0` and debug logging. No handler code, no annotations
beyond what `main` already had.

**Needs SAP AI Core:** no — falls back to `MockAICoreService`.

## Run it

```bash
npm ci && npm run watch
```

Open http://localhost:4004/$fiori-preview/TravelService/Travels → **Create** →
look at *Agency*, *Customer* and *Status*: they are pre-filled in italics with a
highlighted background. Those are Fiori's **soft-fill suggestions**, driven by
`@UI.Recommendations`.

## Verify

The exercise this is based on says you should *"see a message indicating that the
AI plugin is active"*. **You will not.** The plugin logs nothing on startup, and
nothing when it silently falls back to the mock — I grepped every shipped file.
The only trace is `MockAICoreService.cds` in the loaded-model list.

So verify against the model and the payload instead:

```bash
# the plugin rewrites the served model at runtime (not at `cds compile` time)
curl -s -u alice: 'http://localhost:4004/odata/v4/travel/$metadata' | grep -c SAP_Recommendations   # 6

# create a draft, then read it back WITH the recommendations
curl -s -u alice: -X POST http://localhost:4004/odata/v4/travel/Travels \
  -H 'Content-Type: application/json' -d '{"Description":"Ski trip"}'
curl -s -u alice: 'http://localhost:4004/odata/v4/travel/Travels(ID=301,IsActiveEntity=false)?$expand=SAP_Recommendations'

# the ACTIVE entity always returns null — the handler is draft-gated
curl -s -u alice: 'http://localhost:4004/odata/v4/travel/Travels(ID=1,IsActiveEntity=true)?$expand=SAP_Recommendations'
```

## What the plugin generated

From the served `$metadata`, verified:

- a navigation property literally named **`SAP_Recommendations`** — on `Travels`
  **and on `Bookings`**, because the plugin recurses into composition children of
  draft-enabled entities
- companion entities `Travels_Recommendations` / `Bookings_Recommendations`
  (`@cds.persistence.skip`, key `technicalRecommendationsIdentifier : cds.UUID`)
- `@UI.Recommendations` → `Path="SAP_Recommendations"`
- exactly **4 prediction targets**: `Currency_code`, `Status_code`, `Agency_ID`,
  `Customer_ID`

## The point to make on stage

We wrote explicit `@Common.ValueList` annotations for **two** fields (Agency,
Customer) but got **four** recommendation targets. `Currency` and `Status` came
for free, because `@sap/cds/common` contains:

```cds
annotate sap.common.CodeList with @cds.odata.valuelist;
```

Every association to a code list on a draft-enabled entity silently becomes a
recommendation target — and its rows are shipped to SAP AI Core as prediction
context. That is worth knowing *before* you add `@odata.draft.enabled` to
something sensitive.

## These are not predictions

`MockAICoreService` returns **the first non-null value of each target column**.
Proof:

```
recommendation:  Currency=EUR  Status=O  Agency=5  Customer=40
travel ID 1:     Currency=EUR  Status=O  Agency=5  Customer=40
```

Say this out loud before someone concludes RPT-1 is stupid.

## Verified plugin internals (`@cap-js/ai` 1.1.0, read from `node_modules`)

| Claim | Reality |
|---|---|
| context row limit | `.limit(2000)` — **hardcoded**, zero config keys exist |
| ordering of context rows | none — no `ORDER BY`, so the DB picks. Predictions are not reproducible after a reseed |
| columns stripped from context | only `createdAt`, `createdBy`, `modifiedAt`, `modifiedBy`, `cds.LargeBinary`, `cds.Vector` |
| vector embeddings / `cds-ai` CLI / knowledge graph | **not in 1.1.0.** The npm tarball ships 12 files: no `bin/`, no `.docs/`, no `lib/vector_embedding/`. Those are `main`-only (1.2.0-tbd) |
| debug logging | `cds.log.levels['@cap-js/ai'] = 'debug'` mostly prints `undefined` — `LOG.debug(details)` at `lib/handlers/recommendations.js:143` logs an undefined variable |

## Known limitations

- Recommendations fire **only** on a draft read that expands `SAP_Recommendations`.
  Opening an existing travel read-only shows nothing.
- Failures are silent: AI Core errors return `{}`, and >10 target columns or
  >100 row columns logs a warning and returns nothing. A broken binding looks
  identical to "no recommendations".
- `UI.Recommendations` is annotated `Common.Experimental` in SAP's own vocabulary.
