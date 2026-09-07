# 10 — Connecting a real agent

**Adds:** `.mcp.json` (Claude Code) and `.vscode/mcp.json` (VS Code / Copilot),
and `cds.mcp.autowire: false`.

**Needs SAP AI Core:** no — but this branch needs an LLM-backed agent to be
interesting.

## Part 1 — autowiring: zero configuration

`@cap-js/mcp` defaults `cds.mcp.autowire: true`. Remove the key and start the
server:

```bash
jq -c '.mcpServers | keys' ~/.claude.json      # ["context7","serena"]
cds watch
jq -c '.mcpServers | keys' ~/.claude.json      # ["cds:TravelAgentService","cds:TravelService","context7","serena"]
```

Verified content — **one entry per MCP-enabled service**, not one per project:

```json
{
  "cds:TravelService":      { "type": "http", "url": "http://localhost:4004/mcp/travel",
                              "headers": { "Authorization": "Basic YWxpY2U6" } },
  "cds:TravelAgentService": { "type": "http", "url": "http://localhost:4004/mcp/travel-agent",
                              "headers": { "Authorization": "Basic YWxpY2U6" } }
}
```

Then just ask:

```bash
claude -p "list all open travels with their agency and total price"
claude -p "which agencies have the most bookings?"
claude -p "accept travel 5 and tell me what changed"
```

> [!IMPORTANT]
> **`claude -p`, not `claude "…"`.** The exercise this is based on says
> `claude "prompt"`. That opens an *interactive* session seeded with the prompt
> and never exits — useless in a script and awkward on stage. `-p` (`--print`)
> queries, prints and exits.

Expect the agent to call `describe` first and then `query`. It is worth watching
it get the CQL right from the tool description alone.

## Part 2 — the caveats

Every one of these was verified on this branch.

**It edits your home directory, not the project.** The entries land in
`~/.claude.json`, with a plaintext `Basic` credential. On a shared or recorded
machine, that matters.

**Purge depends on how the server dies:**

| how `cds watch` ends | `cds:*` entries |
|---|---|
| Ctrl-C / SIGTERM | **removed cleanly** |
| crash / SIGKILL | **left behind**, pointing at a now-dead port |

After a crash your client shows a broken server until you clean up by hand:

```bash
jq -c '.mcpServers | keys' ~/.claude.json
```

**Exactly two clients are supported** — Claude Code (`~/.claude.json`) and
opencode (`~/.config/opencode/opencode.json`). No VS Code, Cursor, Gemini or
Windsurf.

**It is guarded on the target already existing.** The Claude target checks for
`~/.claude.json` and the opencode target for `~/.config/opencode/`. On a fresh
machine autowire writes **nothing, silently**.

**It only runs when the profile includes `development` and not `test`.**

**The key contains a colon** (`cds:TravelService`), which Claude Code's own docs
advise against. It works — but check `claude mcp list` *before* the session.

## Part 3 — manual registration (what a repo should ship)

```json
{ "cds": { "mcp": { "autowire": false } } }
```

Verified: with this set, `cds serve` leaves `~/.claude.json` untouched.

Then commit the config. **The top-level key differs per client — this is the
single most-copied-wrong line in any MCP workshop:**

`.vscode/mcp.json` — VS Code / GitHub Copilot agent mode uses **`servers`**:

```json
{ "servers": { "cds-travel": {
    "type": "http", "url": "http://localhost:4004/mcp/travel",
    "headers": { "Authorization": "Basic YWxpY2U6" } } } }
```

`.mcp.json` — Claude Code project scope uses **`mcpServers`**, and `type` is
**mandatory** on a `url` entry:

```json
{ "mcpServers": { "cds-travel": {
    "type": "http", "url": "http://localhost:4004/mcp/travel",
    "headers": { "Authorization": "Basic YWxpY2U6" } } } }
```

Or via the CLI — note `<name>` comes **before** the URL, and `--scope` defaults
to `local`, so pass `project` to write the committable file:

```bash
claude mcp add --transport http cds-travel --scope project \
  http://localhost:4004/mcp/travel \
  --header "Authorization: Basic YWxpY2U6"
claude mcp get cds-travel && claude mcp list
```

### The other clients, for reference

| client | file | top-level key | notes |
|---|---|---|---|
| VS Code / Copilot | `.vscode/mcp.json` | `servers` | |
| Claude Code | `.mcp.json` | `mcpServers` | `type` is required on `url` entries |
| Cursor | `.cursor/mcp.json` | `mcpServers` | remote entries need no `type` |
| opencode | `opencode.json` | `mcp` | `type: "remote"`; add `"oauth": false` or a bad Basic header triggers a browser OAuth flow instead of a clean 401 |
| Gemini CLI | `.gemini/settings.json` | `mcpServers` | Streamable HTTP needs **`httpUrl`**, not `url` |

## Which endpoint should the agent get?

This repo exposes two. Point agents at **`/mcp/travel-agent`** — the tailored,
curated projection from branch `09`. `/mcp/travel` exists to show what
annotating a whole service gets you, including the leaked
`*_Recommendations` entities and the draft columns.

For a demo, connecting both is instructive: ask the same question twice and
compare what the agent has to wade through.

## Because this branch changes a file outside the repo

Back it up before rehearsing, and tell attendees who follow along to set
`autowire: false`:

```bash
cp ~/.claude.json ~/.claude.json.backup
```
