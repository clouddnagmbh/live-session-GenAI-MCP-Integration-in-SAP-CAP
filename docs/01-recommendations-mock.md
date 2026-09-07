# 01 — RPT-1 field recommendations (mock)

**Adds:** `@cap-js/ai@1.3.0`, debug logging, and **one line of config** that
undoes the plugin's SQLite redirect (see "The trap on first start"). No handler
code, no annotations beyond what `main` already had.

**Needs SAP AI Core:** no — falls back to `MockAICoreService`.

## Run it

```bash
npm ci && npm run watch
```

Open http://localhost:4004/$fiori-preview/TravelService/Travels → **Create** →
look at *Agency*, *Customer* and *Status*: they are pre-filled in italics with a
highlighted background. Those are Fiori's **soft-fill suggestions**, driven by
`@UI.Recommendations`.

## The trap on first start

With `@cap-js/ai` ≥ 1.2.0 the plain `npm add @cap-js/ai && cds watch` does
**not** start. The plugin's `package.json` redefines `cds.requires.kinds.sqlite`
(`impl: @cap-js/ai/lib/sqlite/AISQLiteService.js`), so every SQLite service in
the project is replaced — and the replacement provisions an ONNX embedding model
before it opens the database:

```
[@cap-js/ai] - Embedding model 'sentence-transformers/all-MiniLM-L6-v2' is not available in
  '/Users/<you>/.cds/models/sentence-transformers/all-MiniLM-L6-v2'. Downloading it now; startup
  is blocked until it finishes and may take a while for large models.
Error: Failed to provision embedding model 'sentence-transformers/all-MiniLM-L6-v2' during startup:
  Automatic Hugging Face model discovery requires @huggingface/hub. Install it with 'npm add -D @huggingface/hub'.
```

The plugin's own `.docs/vector-embeddings.md` says so: *"This applies to every
SQLite service in an application that installs `@cap-js/ai`. Its embedding model
is provisioned and initialized when the service starts, even if the application
does not call `VECTOR_EMBEDDING`."* There is no documented off switch. The
undocumented one is to pin the implementation back:

```json
"cds": { "requires": { "db": { "impl": "@cap-js/sqlite" } } }
```

That is what this branch commits. `cds env requires.db` still shows the
plugin's `embedding.model` key, but `impl` wins and the stock `SQLiteService`
is used. Nothing is downloaded, nothing talks to Hugging Face.

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

## Verified plugin internals (`@cap-js/ai` 1.3.0, read from `node_modules`)

| Claim | Reality |
|---|---|
| context row limit | `.limit(2000)` — **hardcoded**, zero config keys exist |
| ordering of context rows | none — no `ORDER BY`, so the DB picks. Predictions are not reproducible after a reseed |
| columns stripped from context | only `createdAt`, `createdBy`, `modifiedAt`, `modifiedBy`, `cds.LargeBinary`, `cds.Vector` |
| recommendation code vs. 1.1.0 | `lib/handlers/recommendations.js`, `lib/csn-enhancements/recommendations.js`, `srv/AICoreService.js`, `srv/MockAICoreService.js` are **byte-identical** to 1.1.0 (Jul 2026). Everything above still holds |
| vector embeddings / `cds-ai` CLI / knowledge graph | shipped since 1.2.0 (experimental): `bin/cds-ai.js`, `lib/vector_embedding/`, `lib/sqlite/`, `lib/knowledge-graph/`. They need `@huggingface/hub`, `@huggingface/tokenizers`, `onnxruntime-node` as extra dev deps — none of which `npm add @cap-js/ai` installs |
| debug logging | `cds.log.levels['@cap-js/ai'] = 'debug'` prints `[@cap-js/ai] - undefined` — `LOG.debug(details)` at `lib/handlers/recommendations.js:143` logs an undefined variable. Still there in 1.3.0 |

## Known limitations

- Recommendations fire **only** on a draft read that expands `SAP_Recommendations`.
  Opening an existing travel read-only shows nothing.
- Failures are silent: AI Core errors return `{}`, and >10 target columns or
  >100 row columns logs a warning and returns nothing. A broken binding looks
  identical to "no recommendations".
- `UI.Recommendations` is annotated `Common.Experimental` in SAP's own vocabulary.
