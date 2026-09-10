# Changelog

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
