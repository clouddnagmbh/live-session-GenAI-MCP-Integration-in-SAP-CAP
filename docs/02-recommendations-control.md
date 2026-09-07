# 02 — Controlling recommendations, and what really leaves the system

**Adds:** the three `@UI.RecommendationState` forms, plus a `server.js`
transparency hook that logs the exact payload sent to SAP AI Core.

**Needs SAP AI Core:** no.

## The three forms (all verified against `@cap-js/ai` 1.1.0)

```cds
annotate TravelService.Travels with {
  Customer   @UI.RecommendationState: 0;                             // opt OUT
  Agency     @UI.RecommendationState: (TotalPrice > 3000 ? 0 : 1);   // DYNAMIC
  BookingFee @UI.RecommendationState;                                // opt IN (scalar)
};
```

Prediction targets before → after:

| | targets |
|---|---|
| branch 01 | `Currency_code`, `Status_code`, `Agency_ID`, `Customer_ID` |
| branch 02 | `Currency_code`, `Status_code`, `Agency_ID`, **`BookingFee`** (no `Customer_ID`) |

### Dynamic form, verified on real data

```
ID=1  TotalPrice=1643  ->  Agency_ID, BookingFee, Currency_code, Status_code
ID=4  TotalPrice=3079  ->             BookingFee, Currency_code, Status_code
```

```bash
# draftEdit an existing travel, then expand recommendations
curl -s -u alice: -X POST 'http://localhost:4004/odata/v4/travel/Travels(ID=4,IsActiveEntity=true)/TravelService.draftEdit' \
  -H 'Content-Type: application/json' -d '{}'
curl -s -u alice: 'http://localhost:4004/odata/v4/travel/Travels(ID=4,IsActiveEntity=false)?$expand=SAP_Recommendations'
```

**Caveat:** `fieldsWithDisabledRecommendations` is a single object shared across
the whole response. In a **list** read, one row over the threshold suppresses
that field's recommendations for *every* row.

---

## The finding: `@UI.RecommendationState: 0` is not a privacy control

`@cap-js/ai`'s own `README.md:102` states:

> Everything in the remaining columns is forwarded to AI Core. Annotate
> sensitive fields with `@UI.RecommendationState : 0` (or a dynamic expression)
> to keep them out of **both the predictions and the context payload**.

Only the first half is true. The code:

- `lib/csn-enhancements/recommendations.js:48` — `if (def['@UI.RecommendationState'] === 0) return vhFields;`
  removes the field from the **prediction targets** only.
- `lib/handlers/recommendations.js:39-46` — the **context column** filter excludes
  only `modifiedAt`, `modifiedBy`, `createdAt`, `createdBy`, `cds.LargeBinary`
  and `cds.Vector`. It never looks at `@UI.RecommendationState`.

Run it and see for yourself — `server.js` prints:

```
─── payload to SAP AI Core ──────────────────────────────
entity            : TravelService.Travels.drafts
prediction TARGETS: [ 'BookingFee', 'Currency_code', 'Status_code', 'Agency_ID' ]
context rows      : 301
columns per row   : Agency_ID, BeginDate, BookingFee, Currency_code, Customer_ID,
                    Description, DraftAdministrativeData,
                    DraftAdministrativeData_DraftUUID, EndDate, HasActiveEntity,
                    HasDraftEntity, ID, IsActiveEntity, SAP_Recommendations,
                    Status_code, TotalPrice
─────────────────────────────────────────────────────────
```

`Customer_ID` is annotated `: 0`. It is **not** a prediction target — and it is
**still in every one of the 301 context rows sent to SAP AI Core**.

Two further things that payload shows:

- **301 rows**, not 300: the plugin appends the row being predicted to the
  `.limit(2000)` context selection.
- **Draft technical columns travel with the context rows** —
  `DraftAdministrativeData`, `DraftAdministrativeData_DraftUUID`,
  `HasActiveEntity`, `HasDraftEntity`, `IsActiveEntity` and even
  `SAP_Recommendations`. The single *prediction* row does get some of these
  stripped (`lib/handlers/recommendations.js:117-119`); the up-to-2000 *context*
  rows do not.

### So what *are* the real controls?

1. **The entity projection.** Only expose what may leave — this is the only
   control that actually works. See branch `09` for the same idea applied to MCP.
2. The excluded types: `cds.LargeBinary` and `cds.Vector` are never sent.
3. Don't put `@odata.draft.enabled` on an entity carrying data you would not
   send to a third-party inference service.

`@UI.RecommendationState: 0` is a **UX control** — it stops a field being
guessed. Present it as that, never as a privacy boundary.

## Also worth knowing

- `@UI.RecommendationState` **collides with the OData vocabulary.** In `UI.xml`
  the term is `Edm.Byte`: 0=regular, 1=highlighted, 2=warning. The plugin
  repurposes it as 0=off / anything-else-truthy=on. Writing `2` meaning
  "warning" **enables** recommendations. Never explain it as the vocabulary term.
- `BookingFee` (scalar opt-in) appears in the OData payload but **not** in the
  Fiori UI — Fiori Elements does not render recommendations for fields without a
  value help. Verify it with `$expand`, not with your eyes.
- `cds.log.levels['@cap-js/ai'] = 'debug'` is nearly useless: `LOG.debug(details)`
  at `lib/handlers/recommendations.js:143` logs an undefined variable, so you get
  `[@cap-js/ai] - undefined`. The `server.js` hook in this branch is the
  practical substitute.
