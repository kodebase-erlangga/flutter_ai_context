# MCP Server Design — flutter_ai_context

**Status:** Design draft (pre-implementation)  
**Target:** `1.0.0` prototype  
**Transport:** stdio (Cursor / Claude Desktop compatible)  
**Runtime:** Dart — same package, shared graph model

---

## Goals

1. **Plug-and-play for AI agents** — Cursor/Claude dapat membaca konteks proyek Flutter tanpa copy-paste manual `AGENTS.md`.
2. **Graph as source of truth** — MCP membaca `.ai/cache/project_graph.json`, bukan re-parse source.
3. **Local-first** — tidak ada upload kode; server berjalan di mesin developer.
4. **Thin adapter** — reuse `AnalysisPipeline`, `CacheManager`, `ContextCommand`, `DoctorEngine` yang sudah ada.

### Non-goals (v1 prototype)

- Remote/hosted MCP
- Real-time file watcher (agent memanggil `sync` tool jika perlu)
- Write/edit source code
- Mengganti `flutter analyze` atau linter

---

## Architecture

```text
┌─────────────────────────────────────────────────────────┐
│  Cursor / Claude Desktop / other MCP client             │
└───────────────────────────┬─────────────────────────────┘
                            │ stdio (JSON-RPC)
                            ▼
┌─────────────────────────────────────────────────────────┐
│  flutter_ai_context_mcp  (bin/flutter_ai_context_mcp) │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │ Tool handlers│  │ Resource     │  │ Project root  │ │
│  │              │  │ providers    │  │ resolver      │ │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────┘ │
└─────────┼─────────────────┼──────────────────┼─────────┘
          │                 │                  │
          ▼                 ▼                  ▼
   AnalysisPipeline   GraphStore /       flutter_ai_context.yaml
   ContextGenerator   CacheManager       + pubspec discovery
   DoctorEngine
          │
          ▼
   .ai/cache/project_graph.json  (schema v1)
   .ai/context/<scope>.md
   AGENTS.md
```

### Project root resolution

Priority order:

1. Env `FLUTTER_AI_CONTEXT_ROOT` (absolute path)
2. CLI arg `--root` pada spawn MCP server
3. `cwd` dari client (harus root Flutter project dengan `pubspec.yaml`)

Jika tidak ditemukan: tool `status` mengembalikan error dengan instruksi `init`.

---

## MCP surface (v1 prototype)

### Tools

| Tool | Description | Maps to |
|------|-------------|---------|
| `project_status` | FRESH/STALE, last update, file count, schema version | `status` command |
| `list_features` | Daftar feature scopes + member count | `context --list` |
| `get_context` | Context pack Markdown untuk satu scope | `context <scope>` |
| `get_architecture` | Ringkasan SM, flows, evidence | `.ai/architecture.md` or live inference |
| `run_doctor` | Doctor report + readiness score | `doctor` command |
| `sync_context` | Incremental sync jika STALE | `sync` command |

**Optional (phase 2):**

| Tool | Description |
|------|-------------|
| `scan_project` | Full rebuild |
| `query_graph` | Cari node/edge by type, name, feature |
| `get_agents_rules` | Isi `AGENTS.md` |

### Resources (URI templates)

| URI | Content |
|-----|---------|
| `flutter-ai-context://agents` | `AGENTS.md` |
| `flutter-ai-context://architecture` | `.ai/architecture.md` |
| `flutter-ai-context://graph` | `project_graph.json` (read-only) |
| `flutter-ai-context://context/{scope}` | `.ai/context/{scope}.md` |
| `flutter-ai-context://features` | `.ai/features.md` |

Resources berguna untuk client yang prefer `fetch_mcp_resource` over tools.

### Prompts (optional)

| Prompt | Use case |
|--------|----------|
| `flutter-feature-context` | Pre-filled: "You are working on feature {scope}. Context: …" |

---

## Tool schemas (draft)

### `project_status`

```json
{
  "name": "project_status",
  "description": "Check whether flutter_ai_context is initialized and if context is FRESH or STALE.",
  "inputSchema": {
    "type": "object",
    "properties": {},
    "additionalProperties": false
  }
}
```

**Response (text):**

```json
{
  "project": "lms_intelecto",
  "context": "FRESH",
  "graphSchema": 1,
  "filesIndexed": 209,
  "features": 16,
  "lastUpdate": "2026-09-11T08:30:00Z",
  "changedFiles": 0
}
```

### `get_context`

```json
{
  "name": "get_context",
  "description": "Get token-budgeted context pack for a feature scope.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "scope": {
        "type": "string",
        "description": "Feature name (case-insensitive), e.g. presensi, auth"
      }
    },
    "required": ["scope"]
  }
}
```

Returns Markdown body (same as `.ai/context/{scope}.md`).

### `sync_context`

```json
{
  "name": "sync_context",
  "description": "Incrementally update project context when STALE.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "force": {
        "type": "boolean",
        "description": "Run even when FRESH",
        "default": false
      }
    }
  }
}
```

---

## Cursor configuration (example)

```json
{
  "mcpServers": {
    "flutter-ai-context": {
      "command": "dart",
      "args": [
        "run",
        "flutter_ai_context:mcp"
      ],
      "env": {
        "FLUTTER_AI_CONTEXT_ROOT": "${workspaceFolder}"
      }
    }
  }
}
```

Alternatif dev_dependency di proyek Flutter:

```json
{
  "mcpServers": {
    "flutter-ai-context": {
      "command": "dart",
      "args": ["run", "flutter_ai_context:mcp"],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

---

## Package layout (planned)

```text
lib/
  src/
    mcp/
      server.dart           # MCP protocol loop (stdio)
      tool_registry.dart    # tool definitions + dispatch
      resource_registry.dart
      project_session.dart  # root, cache, config per session
bin/
  flutter_ai_context.dart   # existing CLI
  flutter_ai_context_mcp.dart  # MCP entrypoint
```

### Dependencies

Evaluate for v1:

- `mcp_dart` or lightweight stdio JSON-RPC handler (minimize deps)
- Reuse existing `package:flutter_ai_context` internals — no duplicate inference

**Executable in pubspec:**

```yaml
executables:
  flutter_ai_context:
  flutter_ai_context_mcp:
```

Alias pendek `mcp` bisa ditambahkan later.

---

## Implementation phases

### Phase 0 — Design (current)

- [x] Tool/resource inventory
- [x] Project root resolution
- [x] Cursor config example
- [ ] Review against MCP spec 2025-03-26

### Phase 1 — Read-only prototype

- [x] `flutter_ai_context mcp` stdio server (subcommand)
- [x] Tools: `project_status`, `list_features`, `get_context`
- [x] Resources: `agents`, `architecture`, `context/{scope}`
- [x] Integration test with in-memory MCP client
- [x] Doc: setup di README

### Phase 2 — Mutating + graph

- [ ] `sync_context` tool
- [ ] `run_doctor` tool
- [ ] Resource `graph` (with size guard / pagination for large projects)
- [ ] `query_graph` tool (filter by `NodeType`, feature name)

### Phase 3 — 1.0 polish

- [ ] Auto `sync` when STALE before `get_context` (configurable)
- [ ] Prompts template
- [ ] Publish + verify di Cursor MCP settings
- [ ] Dogfood on `lms_intelecto`

---

## Error handling

| Condition | MCP response |
|-----------|--------------|
| Not a Flutter project | `isError: true`, message: run `init` |
| Context never built | suggest `init` or `sync` |
| Unknown scope | list available scopes from `list_features` |
| Schema mismatch | suggest `scan` |
| Graph file missing | trigger full pipeline or error |

Semua error harus **actionable** — sertakan perintah CLI yang tepat.

---

## Security & privacy

- Server hanya membaca file di project root yang di-resolve
- Tidak mengeksekusi kode Dart proyek — hanya `package:analyzer` via pipeline yang sudah ada
- `sync`/`scan` menulis hanya ke `.ai/`, `AGENTS.md`, `.cursor/rules/` — tidak modify `lib/`
- Redaction rules dari `Redaction.sanitize` tetap berlaku pada output

---

## Success criteria (1.0)

1. Cursor agent dapat memanggil `get_context` untuk feature tanpa user paste manual
2. `project_status` menunjukkan FRESH/STALE — agent tahu kapan perlu `sync_context`
3. Dogfood `lms_intelecto`: agent mendapat GetX hybrid + flow presensi dalam satu tool call
4. Zero network — stdio only

---

## Open questions

1. **Dart MCP SDK** — pakai package community (`mcp_server`) atau implement minimal stdio sendiri?
2. **Large graph** — `project_graph.json` 200+ file bisa >1MB; perlu pagination atau summary endpoint?
3. **Monorepo** — multiple `pubspec.yaml`; perlu `--root` wajib?
4. **Executable name** — `flutter_ai_context_mcp` vs subcommand `flutter_ai_context mcp serve`?

Rekomendasi awal: subcommand `mcp` di CLI yang sama (satu executable, satu pub cache entry).

---

## Related docs

- [GRAPH_SCHEMA_v1.md](GRAPH_SCHEMA_v1.md) — graph contract MCP reads
- [architecture.md](architecture.md) — pipeline overview
- [README.md](../README.md) — CLI workflow
