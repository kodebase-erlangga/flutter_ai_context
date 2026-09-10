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

```bash
dart pub global activate flutter_ai_context
```

Add pub cache bin to your PATH:

- **macOS/Linux:** `$HOME/.pub-cache/bin`
- **Windows:** `%LOCALAPPDATA%\Pub\Cache\bin`

Or run without global install:

```bash
dart pub global activate --source path .
flutter_ai_context init
```

## Quick Start

```bash
cd your_flutter_project
flutter_ai_context init
flutter_ai_context doctor
flutter_ai_context context auth
```

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
| `scan` | Full project re-analysis |
| `sync` | Incremental update for changed files |
| `status` | Check whether context is fresh or stale |
| `doctor` | Compare code against declared rules and dominant patterns |
| `context <scope>` | Generate focused context pack for a feature |

Global flags: `--verbose`, `--quiet`, `--version`, `--help`

## Generated Files

```text
project/
├── flutter_ai_context.yaml
├── AGENTS.md
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

## Limitations (v0.3.0)

- Semantic resolution uses `AnalysisContextCollection` with Element2 fragment fallback and AST heuristics when the SDK context is incomplete.
- `auto_route` support covers common `AutoRoute` / `@RoutePage` patterns; deep nested routing is not fully supported yet.
- Incremental `sync` re-scans changed files and direct dependents; transitive invalidation is still limited.
- Doctor rules are expanding but not a replacement for `flutter analyze` or custom linters.
- **Pre-1.0 API** — graph schema and CLI output may change before `1.0.0`.

## Development

```bash
dart pub get
dart test
dart analyze
dart format .
dart run bin/flutter_ai_context.dart --help
```

## Roadmap

- `0.4.0` — context pack relevance improvements, transitive sync invalidation
- `1.0.0` — stable schema/CLI contracts
- Future: MCP server consuming the same Project Knowledge Model

## Release Notes

See [CHANGELOG.md](CHANGELOG.md) and [doc/RELEASE_v0.2.0.md](doc/RELEASE_v0.2.0.md).

## License

MIT — see [LICENSE](LICENSE).
