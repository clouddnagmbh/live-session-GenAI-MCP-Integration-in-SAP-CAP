# 04 — A real generative call (SAP Cloud SDK for AI)

**Adds:** `@sap-ai-sdk/orchestration@2.15.0`, an `LLM` CAP service with two
implementations, and a `TravelAssistant.summarize()` function that uses it.

**Needs SAP AI Core:** the *real* path needs SAP Generative AI Hub. The branch
runs **fully offline** on a local implementation, and the profile switch to the
real one is config-only.

## Why this branch exists

SAP-RPT-1 — everything in branches 01–03 — is a **relational** foundation model.
It predicts table cells. It is not generative and it does not talk.

`@cap-js/ai` gives you RPT-1 recommendations, an AI Core admin service, and
(unreleased) local embeddings. It gives you **no LLM chat capability at all**.
So a session called "GenAI & MCP in SAP CAP" that stops at branch 03 has not
actually shown any generative AI. This branch is that missing half.

## Try it

```bash
npm ci && npm run watch
curl -s -u alice: 'http://localhost:4004/odata/v4/travel-assistant/summarize(travelID=1)'
```

```json
{
  "travelID": 1,
  "summary": "Wellness retreat to Munich booked through Bayern Tours for 12 nights, totalling 1643.0000 EUR. Current status: Open. [mock summary — no language model was called]",
  "model": "mock",
  "mocked": true,
  "promptTokens": 28,
  "completionTokens": 41
}
```

`mocked: true` is returned on purpose. Never let a demo blur whether a model ran.

## The pattern: an LLM as a CAP service

`llm/LLM.cds` models the LLM the same way `@cap-js/ai` models `AICore` — a
verified copy of that plugin's own approach:

```cds
@impl: './orchestration.js'
@protocol: 'none'
service LLM {
  action chat(system : String, user : String) returns { ... };
}
```

- **`@protocol: 'none'`** keeps it off HTTP. Internal callers only.
- **`@impl`** binds the implementation *in the model*, so the swap is a model
  swap, not a code change. `llm/LLM-mock.cds` is the entire mock wiring:

```cds
using { LLM } from './LLM';
annotate LLM with @impl: './mock.js';
```

Selected by profile in `package.json`:

```json
{ "cds": { "requires": {
  "LLM":          { "model": "llm/LLM-mock", "kind": "llm-mocked" },
  "[hybrid]":     { "LLM": { "model": "llm/LLM", "kind": "llm-aicore" } },
  "[production]": { "LLM": { "model": "llm/LLM", "kind": "llm-aicore" } }
}}}
```

`TravelAssistant` just does `cds.connect.to('LLM')` and `llm.send('chat', …)`.
It never imports an AI SDK, so it is testable with no network and no entitlement.

### Verified: the switch really switches

```bash
CDS_ENV=hybrid cds serve
curl -s -u alice: 'http://localhost:4004/odata/v4/travel-assistant/summarize(travelID=1)'
```

```json
{"error":{"code":"502","message":"SAP Generative AI Hub call failed: Failed to fetch the list of deployments.. The SDK needs AICORE_SERVICE_KEY or a VCAP binding labelled 'aicore'."}}
```

That error comes from **the real SDK**, reaching out and failing only at the
credential boundary. Good demo: the audience sees live SDK code, and you never
have to pretend you have an entitlement.

## The API (verified against SAP's own docs, Sept 2026)

```js
import { OrchestrationClient } from '@sap-ai-sdk/orchestration'

const client = new OrchestrationClient({
  promptTemplating: { model: { name: 'gpt-5' } }
})
const res = await client.chatCompletion({
  messages: [{ role: 'system', content: '…' }, { role: 'user', content: '…' }]
})
res.getContent(); res.getFinishReason(); res.getTokenUsage()
```

> **Pin the major.** v1 called the module `templating`; v2 renamed it to
> **`promptTemplating`**. A v1 snippet silently fails against 2.x.

Embeddings use a separate client in the same package, if you ever need them:

```js
const embeddingClient = new OrchestrationEmbeddingClient({
  embeddings: { model: { name: 'text-embedding-3-large' } }
})
const data = (await embeddingClient.embed({ input: 'AI is fascinating' })).getEmbeddings()
```

## The gotcha worth a slide: two credential mechanisms

`@cap-js/ai` and `@sap-ai-sdk/*` both talk to SAP AI Core, and they find their
credentials **differently**:

| | resolves credentials from |
|---|---|
| `@cap-js/ai` (`AICore` CAP service) | `cds.requires.AICore.credentials` — i.e. what `cds bind` writes |
| SAP Cloud SDK for AI | `AICORE_SERVICE_KEY`, or a **VCAP** binding labelled `aicore` (`packages/core/src/context.ts`) |

So `cds bind AICore -2 …` alone does **not** make the Cloud SDK work. The bridge
is `cds bind --exec`, which injects the resolved bindings as `VCAP_SERVICES`:

```bash
cds bind --exec -- cds serve --profile hybrid
```

Expect to trip over this the first time you combine both in one app.

## Honesty about the local implementation

`llm/mock.js` is **not** a language model. It pulls the figures back out of the
prompt and formats them into a sentence. It exists to prove the contract, the
wiring and everything downstream of the call — nothing else. It is deterministic,
which is a feature on stage.

## The prompt is the trust boundary

`srv/travel-assistant.js` builds the prompt from six explicitly chosen fields.
Whatever you put in that string leaves the system. Compare with branch `02`,
where `@cap-js/ai` decides for you and ships up to 2000 rows — including columns
you thought you had excluded.
