# Changelog

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
