# 12 — A CAP-level agent (`@cap-js/agents`)

**Adds:** `@cap-js/agents@0.9.11`, one annotate statement, `cds.requires.llm`,
one quota, and `a2a-send.sh`.

**Needs SAP AI Core:** no — `llm: mock`. `--profile hybrid` switches to
`aicore` (SAP Generative AI Hub via the Cloud SDK, wrapped by the plugin).

**Status:** Node.js **Gamma**, Java Alpha (capire release notes, October 2026).
The guide page itself carries no status word except "Chat Preview — Alpha".

## The whole change

```cds
using { TravelAgentService } from './travel-agent-service';
annotate TravelAgentService with @agent;
```

```json
{ "cds": { "requires": { "llm": "mock", "[hybrid]": { "llm": "aicore" } },
           "agents":   { "quotas": { "maxIncomingMessageLength": 200 } } } }
```

```
[cds] - serving TravelAgentService {
  at: [ '/a2a/travel-agent', '/mcp/travel-agent' ],
}
[agents] - cds.connect.to 'llm' with: { impl: '@cap-js/agents/lib/models/mock', kind: 'mock' }
```

The same service branch `09` curated for *other people's* agents is now also
**an agent of its own**, hosted by CAP, speaking A2A. The plugin builds the
tools from the service — the same `describe` / `query` / `call` as branch `06`,
internally via `@cap-js/mcp` — and runs a ReAct loop against `cds.requires.llm`.

## Try it

```bash
./a2a-send.sh "list three travels with their agency" | jq -r '.result.status.message.parts[0].text'
```
```
[Mock LLM] This is a mocked response from @cap-js/agents development mode. No real LLM was invoked.

Tool result: count: 300
data[3]{ID,Description,BeginDate,EndDate,TotalPrice,Currency,Status,Agency,AgencyCity}:
  1,Wellness retreat to Munich,2027-03-05,2027-03-17,"1643.0000",EUR,Open,Bayern Tours,Munich
  2,Hiking tour to Rome,2026-11-18,2026-11-24,"2777.0000",EUR,Open,Bella Italia Tours,Rome
```

Server log, which is the better thing to show on stage:

```
[agents] - TravelAgentService request { method: 'message/send', text: 'list three travels with their agency' }
[mcp]    - TravelAgentService query { cql: 'SELECT * FROM Travels LIMIT 3' }
[agents] - TravelAgentService completed { conversation: '23cb7c2a', duration: '0.0s' }
```

Also served, with no further work:

| | |
|---|---|
| agent card | `GET /a2a/travel-agent/.well-known/agent-card.json` — `protocolVersion: 0.3.0`, skills `query` and `call-recommendAgency` (from branch `11`) |
| chat preview (Alpha) | http://localhost:4004/a2a/travel-agent/preview/ — linked from the index page's new **Agents** section (cds 10.2) |
| task API | `tasks/get` with the returned task `id` |
| `GET /a2a/travel-agent` | **405** — JSON-RPC, POST only (same as MCP, branch `06`) |

> [!NOTE]
> **The mock is not reasoning.** `lib/models/mock.js` always emits one `query`
> tool call — `SELECT * FROM <first entity> LIMIT 3` — then echoes the tool
> result behind a fixed sentence. Deterministic, which is the point on stage.
> Switch the profile and a real model reads the same tools.

## `cds.requires.llm` — the pattern from branch `04`, productised

| kind | what it does |
|---|---|
| `mock` | the mock above |
| `aicore` | SAP AI Core / Generative AI Hub through the Cloud SDK (default for `hybrid` and `production`; default model `anthropic--claude-4.6-sonnet`) |
| `auto` | **default for `development`**: resolves credentials from `ANTHROPIC_*` / `OPENAI_*` env vars, then **`~/.claude/settings.json`**, `~/.config/opencode/opencode.json`, `~/.codex/config.toml`; falls back to `mock` |
| `anthropic`, `openai` | the explicit forms `auto` resolves to (undocumented on capire, present in `cds-plugin.js`) |

Verified on this machine with `CDS_REQUIRES_LLM=auto`:

```
[agents] - cds.connect.to 'llm' with: { kind: 'anthropic', model: undefined,
  credentials: { anthropicApiUrl: 'https://api.anthropic.com' } }
```

That is branch `10`'s autowire in the opposite direction: there the CAP app
*wrote* the agent's config; here it *reads* it. Both are development
conveniences that touch your home directory, and both are why this branch pins
`mock` instead of leaving the default.

Branch `04`'s hand-built `LLM` service stays — `recommendAgency` still uses it.
Two LLM abstractions in one app is deliberate here (one shows the pattern, one
ships it); in a real project pick `cds.requires.llm`.

## Governance that exists now (and what still does not)

Verified:

| control | result |
|---|---|
| `maxIncomingMessageLength: 200`, 300-char message | `-32029 The message must not exceed 200 characters.` — rejected **before any model call** |
| anonymous | **401** |
| `nobody` (no role) | `-32003 Forbidden` |
| `viewer` | works — the agent runs **as the caller**, so branch `09`'s `@restrict` and the per-user tool filtering apply to what the model can reach |

Available but not exercised here: `@agent.hitl` on an action (task goes to
`input-required` until a human answers — the mock never calls `call`, so there is
nothing to pause); audit events (`AgentDecision`, `ToolInvocation`,
`QuotaExceeded`, …) via the optional `@cap-js/audit-logging` peer; metrics via
`@cap-js/telemetry`; the full `cds.agents.quotas` set (per user, per hour, per
task, token budgets, timeouts).

Still nobody's job but yours: prompt-injection in the data the model reads
(branch `09`), and anything that calls `/mcp/travel-agent` from *outside* — the
quotas and audit log cover agents CAP hosts, not agents that merely consume
your MCP endpoint.

## The price of `npm add @cap-js/agents`

- **72 packages**, `node_modules` 205 MB: LangChain, LangGraph, `deepagents`,
  the A2A SDK, `@sap-ai-sdk/*`, and `@cap-js/mcp ^1.5` as a hard dependency.
- **`@cap-js/attachments` is a hard dependency too**, and being a cds-plugin it
  loads itself: `node_modules/@cap-js/attachments/index.cds` and `db/index.cds`
  appear in your model list whether or not you use attachments.
- `@cap-js/agents/srv/entities.cds` adds the task/conversation persistence
  entities to your database.

Same lesson as branch `01`: a plugin is a model change, not just a dependency.
