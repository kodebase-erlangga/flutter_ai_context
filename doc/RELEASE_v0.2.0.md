# Release Notes — v0.2.0

**Release date:** 2026-09-09  
**Status:** Early release (pre-1.0)  
**Tagline:** Give AI a real understanding of your Flutter project.

---

## Highlights

v0.2.0 upgrades the scanner from AST-only heuristics to a **semantic-aware pipeline** with route detection, richer state-management signals, and golden-tested Markdown output.

### New capabilities

1. **Semantic session** (`AnalysisContextCollection`)
   - Resolves Dart units when analyzer context is available
   - AST fallback for fixtures and unresolved SDK types
   - Stable symbol registry for `calls`, `depends_on`, `watches` edges

2. **Route understanding**
   - Detects `GoRoute(path:)`, `context.go/push`, `Navigator.pushNamed`
   - Generates `.ai/routes.md` with path → screen mappings

3. **Riverpod & GetX detection**
   - Signals: `@riverpod`, `ref.watch/read`, `ConsumerWidget`, `GetxController`, `Get.put/find`, `Obx`, `.obs`
   - Framework metadata on graph nodes (`stateManagementFramework`)

4. **Architecture flows**
   - `Screen -> Riverpod Notifier -> Repository`
   - `Screen -> Bloc -> Repository`
   - Existing Provider flows preserved

5. **Golden tests**
   - Snapshot tests for `architecture.md` and `routes.md` output

6. **Bug fix: config YAML**
   - Glob patterns like `**/*.g.dart` are now quoted when writing `flutter_ai_context.yaml` (fixes YAML alias parse errors)

---

## Dogfood validation

Tested on real project **`lms_intelecto`** (209 Dart files, 10 features):

| Metric | Result |
|--------|--------|
| State management | Provider (99%), trace GetX (1%) |
| Networking | Dio |
| Features detected | Auth, Beranda, Chat, Nilai, Notifikasi, Presensi, … |
| Doctor | No issues, AI Readiness **78/100** |
| Scan time | ~90s (full init, Windows) |

Tested on fixture **`provider_feature_first`**:

| Metric | Result |
|--------|--------|
| Dominant flow | `Screen -> Provider -> Service` |
| Context pack `attendance` | ~401 tokens |
| Doctor | AI Readiness **92/100** |

---

## Breaking changes

None intended for CLI commands. Graph schema remains **v1** but internal edge confidence semantics improved.

---

## Known issues

- `status` may show `Files analyzed: 0` when metadata not refreshed — use `scan` to rebuild
- Projects without Flutter SDK resolution fall back to AST heuristics for supertype detection
- `auto_route` not yet supported
- Duplicate entries can appear in `features.md` when multiple graph nodes map to the same file path

---

## Upgrade guide

```bash
dart pub global activate flutter_ai_context
cd your_flutter_project
flutter_ai_context scan   # rebuild graph + context
```

If `doctor` fails with `Undefined alias` in config, regenerate config or quote glob patterns:

```yaml
ignore:
  - '**/*.g.dart'
  - '**/*.freezed.dart'
```

---

## Pub.dev publish audit

```
dart pub publish --dry-run
→ Package has 0 warnings
→ Archive size: ~37 KB
```

---

## What's next (0.3.0)

- Expanded doctor rules from `flutter_ai_context.yaml`
- Cross-file semantic invalidation for `sync`
- `auto_route` detection
- Element2 analyzer migration
- Performance benchmarks on medium/large fixtures

---

## Contributors

Built by Kodebase ERL. Issues and PRs welcome on GitHub.
