# flutter_ai_context

[![pub package](https://img.shields.io/pub/v/flutter_ai_context.svg)](https://pub.dev/packages/flutter_ai_context)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Give AI a real understanding of your Flutter project.**

`flutter_ai_context` is a local-first project intelligence layer for Flutter codebases. It analyzes your project, infers architectural patterns, builds a **Project Knowledge Graph**, and generates concise context for AI coding agents — without uploading your source code.

> AI does not need more source code. AI needs the **right project context**.

## Features

- **Local-first** — deterministic, offline-capable analysis via `package:analyzer`
- **Project Knowledge Graph** — structured nodes/edges persisted in `.ai/cache/project_graph.json`
- **Observed vs Declared Truth** — infer patterns from code, compare with `flutter_ai_context.yaml`
- **Architecture inference** — Provider, Riverpod, Bloc, GetX flows with confidence/evidence
- **Route detection** — GoRouter, Navigator, `context.go` / `pushNamed`
- **Doctor** — architecture consistency checks + AI readiness score
- **Context packs** — focused per-feature Markdown for agents (`context attendance`)
- **Incremental sync** — hash-based cache for faster updates

## Installation

### Option A — dev dependency (recommended for teams)

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_ai_context: ^0.6.0
```

```bash
dart pub get
dart run flutter_ai_context init
dart run flutter_ai_context sync    # day-to-day after edits
dart run flutter_ai_context status    # FRESH / STALE
```

### Option B — global CLI

```bash
dart pub global activate flutter_ai_context
```

Add pub cache bin to your PATH:

- **macOS/Linux:** `$HOME/.pub-cache/bin`
- **Windows:** `%LOCALAPPDATA%\Pub\Cache\bin`

```bash
flutter_ai_context init
```

## Quick Start

```bash
cd your_flutter_project
dart run flutter_ai_context init      # or: flutter_ai_context init
dart run flutter_ai_context doctor
dart run flutter_ai_context context auth
# after code changes:
dart run flutter_ai_context sync
```

`init` creates `AGENTS.md`, `.ai/`, and `.cursor/rules/flutter-ai-context.mdc` (Cursor onboarding).

### Example output (`init`)

```text
Flutter AI Context

✓ Flutter project detected
✓ Scanning project structure
✓ Detecting dependencies
✓ Analyzing Dart code
✓ Detecting architecture
✓ Building project knowledge graph
✓ Generating AI context

Detected:
State Management : Provider
Networking       : Dio
Routing          : GoRouter
Architecture     : Feature-based
Testing          : flutter_test

AI context initialized successfully.
```

### Example `AGENTS.md` (generated)

```md
# Flutter Project Context

Primary state management:
Provider

Observed architecture:
Screen -> Provider -> Service (100% confidence).

Important rules:
- Follow existing feature structure.
- Use Provider for new state-management code unless a feature is explicitly marked as legacy.
- Do not call HTTP APIs directly from UI widgets.
- Reuse existing services and models before creating new ones.
- Use `.ai/` for detailed project context.

Canonical architecture reference:
`lib/features/auth/`
```

## Commands

| Command | Description |
|---------|-------------|
| `init` | Initial discovery, config, and first context generation |
| `sync` | **Default workflow** — incremental update for changed files |
| `status` | Check whether context is **FRESH** or **STALE** |
| `scan` | Full project re-analysis (schema upgrade / major refactor) |
| `doctor` | Compare code against declared rules and dominant patterns |
| `context <scope>` | Generate focused context pack for a feature |

Global flags: `--verbose`, `--quiet`, `--version`, `--help`

## Generated Files

```text
project/
├── flutter_ai_context.yaml
├── AGENTS.md
├── .cursor/rules/flutter-ai-context.mdc
└── .ai/
    ├── project.md
    ├── architecture.md
    ├── dependencies.md
    ├── conventions.md
    ├── features.md
    ├── routes.md
    ├── services.md
    ├── models.md
    ├── context/
    └── cache/
        ├── project_graph.json
        ├── files.json
        └── scan_metadata.json
```

> Markdown files are **consumers** of the Project Knowledge Graph — not the source of truth.

## Observed vs Declared Truth

**Observed Truth** — inferred from actual code (e.g. "Provider used in 84% of flows").

**Declared Truth** — configured in `flutter_ai_context.yaml`:

```yaml
architecture:
  state_management: riverpod

rules:
  architecture:
    direct_http_from_ui: false
```

When they conflict, both are reported with migration guidance.

## Configuration

```yaml
project:
  name: my_flutter_app

architecture:
  state_management: auto
  routing: auto
  networking: auto

scan:
  paths:
    - lib
    - test
  ignore:
    - build/**
    - '**/*.g.dart'
    - '**/*.freezed.dart'

context:
  output: .ai
  generate_agents_md: true
  generate_cursor_rule: true

rules:
  architecture:
    direct_http_from_ui: auto
```

> Glob patterns with `*` must be quoted in YAML.

## Supported Patterns

| Area | Detection |
|------|-----------|
| State management | Provider, Riverpod, Bloc/Cubit, GetX |
| Architecture flows | Screen → Provider/Bloc/Notifier → Service/Repository |
| Routing | GoRouter `GoRoute`, Navigator `pushNamed`, `context.go` |
| Structure | Feature-first and layer-first clustering |
| Networking | Dio, http (dependency + usage signals) |

## Privacy

All analysis runs locally. No source code is uploaded. Secret-like strings are redacted from generated output.

## Documentation

| Doc | For |
|-----|-----|
| [doc/architecture.md](doc/architecture.md) | How the pipeline works (human-readable) |
| [doc/GRAPH_SCHEMA_v1.md](doc/GRAPH_SCHEMA_v1.md) | Graph JSON contract, node/edge types, versioning |
| [doc/MCP_DESIGN.md](doc/MCP_DESIGN.md) | MCP server design for 1.0 (draft) |

Graph schema **v1** is frozen for the 1.0 track. You can open `.ai/cache/project_graph.json` after `init` — the schema doc explains how to read it.

## Limitations (v0.6.0)

- Semantic resolution uses parse-once caching with selective lazy resolution and Element2 fragment fallback when the SDK context is incomplete.
- `*Page` / `pages/` widgets are treated as screens; GetX hybrid `ChangeNotifier` controllers in `controllers/` paths are detected as GetX.
- `auto_route` support covers common `AutoRoute` / `@RoutePage` patterns; deep nested routing is not fully supported yet.
- Incremental `sync` re-scans changed files, graph dependents, and import dependents (bounded by cached metadata).
- Context packs use feature-scoped graph ranking, class signatures, and a configurable token budget (`context.token_budget`).
- Doctor info findings are shown separately and do not reduce the readiness score; warnings still do.
- Doctor rules are expanding but not a replacement for `flutter analyze` or custom linters.
- Graph schema v1 is stable; breaking graph changes require a major version bump.
- CLI/MCP integrations may still evolve before `1.0.0`.

## Development

```bash
dart pub get
dart test
dart analyze
dart format .
dart run bin/flutter_ai_context.dart --help
```

## Roadmap

- `1.0.0` — stable schema/CLI contracts, MCP server prototype ([design draft](doc/MCP_DESIGN.md))
- Future: MCP tools for `get_context`, `project_status`, `sync_context`

## Release Notes

See [CHANGELOG.md](CHANGELOG.md) and [doc/RELEASE_v0.2.0.md](doc/RELEASE_v0.2.0.md).

## License

MIT — see [LICENSE](LICENSE).
