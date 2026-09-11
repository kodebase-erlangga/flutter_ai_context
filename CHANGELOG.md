# Changelog

## 0.6.0

### Added
- Graph-based hybrid state management detection (architectural nodes outweigh Consumer/context.read signals)
- Frozen graph schema v1 contract: [doc/GRAPH_SCHEMA_v1.md](doc/GRAPH_SCHEMA_v1.md)
- Cursor onboarding rule: `.cursor/rules/flutter-ai-context.mdc` on init (`context.generate_cursor_rule`)
- `sync` + `status FRESH/STALE` as the documented default workflow

### Improved
- `sync` and `status` report context freshness, changed file counts, and schema version
- `init` prints next-step workflow (`sync` after edits, `scan` for full rebuilds)
- Schema mismatch on cache load triggers rebuild with a clear message
- Graph-first primary SM with DI-layer detection (GetX architecture + Provider widget signals)
- Human-readable docs: [doc/architecture.md](doc/architecture.md), [doc/GRAPH_SCHEMA_v1.md](doc/GRAPH_SCHEMA_v1.md)

## 0.5.3

### Improved
- Shared flow inference distinguishes GetX, Riverpod, Provider, and StatefulWidget patterns
- Context packs include Agent Guide, Entry Points, and a dedicated Widgets section
- `context.read<T>()` / `context.watch<T>()` edges improve repository and controller detection
- Faster scans via AST-based semantic skip for constants, theme, and non-interactive files

## 0.5.2

### Improved
- Scan performance: parse-once AST cache, selective semantic resolution, batched resolves
- Context ranker includes `core/` and `shared/` files imported directly by a feature
- Context ranker supports `modules/` feature paths
- GetX hybrid detection for ChangeNotifier controllers and `*Binding` classes
- Context packs dedupe Related Nodes and use incremental token budgeting

## 0.5.1

### Fixed
- Detect `*Page` / `pages/` widgets as screens (GetX and page-first projects)
- Context ranker scopes results to the target feature folder (less cross-feature noise)
- Context pack signatures prefer the primary class per file over inner types
- Doctor separates warnings vs info; `feature.missing_screen` respects Page widgets
- Doctor readiness score ignores info-severity findings
- `context` CLI lists only files included in the token-budgeted pack

### Added
- `getx_pages` benchmark fixture (24 Dart files, page-first GetX layout)
- Tests for doctor scoring and context pack selection

## 0.5.0

### Added
- `flutter_ai_context context --list` to discover available feature scopes
- Class signatures in context packs (supertype + key methods from graph metadata)
- Import-graph sync invalidation (re-scan files that import changed modules)
- Lazy per-file semantic resolution for faster scans
- Golden test for attendance context pack output

### Improved
- Doctor `screen_bypasses_state_management` ignores test/generated files and watch/read edges
- Context pack file entries now include compact class signatures

## 0.4.0

### Added
- Graph-distance context pack ranking with role-aware scoring (screen → state → data)
- Context packs grouped by layer with observed feature flow
- Configurable context token budget (`context.token_budget`, default `2000`)
- Scope suggestions when `context <scope>` does not match a feature
- Transitive sync invalidation across dependent graph nodes

### Changed
- `context` output now includes score, observed flow, and grouped sections

## 0.3.0

### Added
- Expanded doctor rules: declared vs observed state management, http in UI, screen bypassing state layer, feature missing screen, routing mismatch, provider suffix
- `auto_route` detection (`AutoRoute`, `@RoutePage`, `@AutoRoute`)
- Cross-file sync invalidation for direct graph dependents
- Element2 fragment fallback for supertype resolution
- Benchmark tests for fixture scan performance
- Fixture: `auto_route_feature`

### Fixed
- `status` now reports total indexed files instead of `0` after incremental sync
- `features.md` deduplicates file paths per feature cluster

## 0.2.1

- Re-publish under verified publisher `sangga.id` (transfer via pub.dev Admin)

## 0.2.0

### Added
- Semantic session via `AnalysisContextCollection` with AST fallback
- Symbol registry for stable graph relationship targets
- GoRouter / Navigator route detection and `.ai/routes.md` generation
- Riverpod/GetX signal detector (`ref.watch`, `@riverpod`, `GetxController`, `Obx`, `.obs`)
- Golden tests for generated Markdown
- Fixtures: Riverpod, Bloc clean, GetX, migration scenario
- Release notes: `doc/RELEASE_v0.2.0.md`

### Fixed
- `flutter_ai_context.yaml` writer now quotes glob patterns (`'**/*.g.dart'`) to avoid YAML alias errors

### Dogfood
- Validated on `lms_intelecto` (209 Dart files, 10 features, Provider + Dio)

## 0.1.0

- Initial release
- CLI commands: `init`, `scan`, `sync`, `status`, `doctor`, `context`
- Analyzer-backed Dart scanning and Project Knowledge Graph
- Architecture/state management inference with confidence/evidence
- Feature clustering (feature-first and layer-first)
- Context generation (`.ai/*.md`, `AGENTS.md`)
- Incremental cache with file hashing
- Doctor rule engine with AI readiness score
- Focused context packs with token estimation
- Test fixtures and CI pipeline
