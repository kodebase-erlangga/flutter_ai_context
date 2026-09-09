# Architecture

`flutter_ai_context` is a Dart CLI package that builds a **Project Knowledge Graph** from Flutter/Dart source code and generates AI-facing context from that graph.

## Pipeline

```
Project Discovery → Dependency Scan → Dart AST Analysis → Pattern Inference
       → Observed Truth + Declared Truth → Context Resolution → Generators
```

## Internal Modules

| Module | Responsibility |
|--------|----------------|
| `discovery/` | pubspec parsing, file indexing, dependency classification |
| `scanner/` | AST traversal, multi-signal classifiers |
| `graph/` | Versioned node/edge model with stable IDs |
| `inference/` | State management, architecture flows, features, naming |
| `rules/` | Doctor engine comparing declared vs observed truth |
| `generators/` | Markdown/AGENTS.md consumers of the graph |
| `cache/` | File hashes, graph persistence, incremental sync |
| `context/` | Relevance ranking and token estimation for context packs |

## Design Principles

1. Graph/model first, Markdown second
2. Deterministic, evidence-backed confidence scores
3. No hardcoded "correct" Flutter architecture
4. Local-first — no source upload
5. Incremental analysis via content hashes

## Graph Schema

Persisted at `.ai/cache/project_graph.json` with `schemaVersion: 1`.

Node types include: `screen`, `provider`, `service`, `feature`, `model`, `route`, etc.

Edge types include: `contains`, `calls`, `depends_on`, `belongs_to_feature`, etc.
