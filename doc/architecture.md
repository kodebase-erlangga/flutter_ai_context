# Architecture

`flutter_ai_context` adalah CLI Dart yang menganalisis codebase Flutter secara **lokal**, membangun **Project Knowledge Graph**, lalu menghasilkan konteks untuk AI coding agent — tanpa mengunggah source code.

Dokumen ini untuk orang yang ingin memahami *bagaimana* package ini bekerja di dalam. Untuk cara pakai sehari-hari, mulai dari [README](../README.md).

---

## Gambaran besar

```text
  pubspec + lib/
        │
        ▼
  Project Discovery ──► daftar file, dependensi, kandidat arsitektur
        │
        ▼
  Dart AST Scanner ──► class, import, call, watch/read
        │
        ▼
  Project Knowledge Graph ──► node + edge (disimpan di .ai/cache/)
        │
        ├──► Inference ──► state management, flow, feature, naming
        │
        ├──► Doctor ──► bandingkan kode vs flutter_ai_context.yaml
        │
        └──► Generators ──► AGENTS.md, .ai/*.md, context packs
```

**Prinsip utama:** graph dulu, Markdown belakangan. File `.md` bisa di-regenerate; graph adalah model yang konsisten.

---

## Alur pipeline

### 1. Discovery

Membaca `pubspec.yaml`, mengindeks file Dart di path yang dikonfigurasi (`lib`, `test`, dll.), dan mengklasifikasi dependensi (Dio, Provider, GoRouter, …).

### 2. Scan & klasifikasi

`package:analyzer` mem-parsing AST. Setiap file diklasifikasi: screen, provider, service, repository, route, dan sebagainya. Hubungan semantik (import, call, `context.read`, navigasi) ditambahkan sebagai edge.

### 3. Graph

Hasil scan disatukan ke graph berversi. Detail struktur data: **[GRAPH_SCHEMA_v1.md](GRAPH_SCHEMA_v1.md)**.

Lokasi cache:

```text
.ai/cache/
  project_graph.json   ← graph utama
  schema_version       ← penanda versi (saat ini: 1)
  files.json           ← hash per file (untuk sync)
  scan_metadata.json   ← waktu scan terakhir, jumlah file
```

### 4. Inference

Dari graph, package menyimpulkan:

- **State management** — graph nodes diutamakan; signal `Consumer`/`context.read` sebagai pelengkap
- **Architecture flow** — mis. `Screen → Provider → Service`
- **Feature clustering** — pengelompokan berdasarkan folder / import graph
- **Canonical reference** — contoh file arsitektur representatif

### 5. Observed vs declared truth

`flutter_ai_context.yaml` bisa mendeklarasikan arsitektur (mis. `state_management: riverpod`). Doctor membandingkan deklarasi dengan apa yang benar-benar terlihat di graph — berguna untuk proyek migrasi.

### 6. Generators

Menulis output yang dibaca manusia dan AI:

| Output | Isi |
|--------|-----|
| `AGENTS.md` | Aturan singkat untuk agent |
| `.ai/architecture.md` | Flow & state management terobservasi |
| `.ai/features.md` | Daftar feature |
| `.ai/context/<scope>.md` | Context pack per feature (token-budgeted) |
| `.cursor/rules/flutter-ai-context.mdc` | Onboarding Cursor (opsional) |

Semua generator **membaca graph**, bukan mem-parse ulang source code.

---

## Modul internal

| Folder | Tanggung jawab |
|--------|----------------|
| `discovery/` | Pubspec, indexing file, klasifikasi dependensi |
| `scanner/` | AST traversal, classifier multi-signal |
| `graph/` | Model node/edge, serialisasi JSON, versi schema |
| `inference/` | State management, flow, feature, naming |
| `rules/` | Doctor — declared vs observed |
| `generators/` | AGENTS.md, Markdown, Cursor rule |
| `cache/` | Hash file, persist graph, incremental sync |
| `context/` | Ranking relevansi & estimasi token untuk context pack |

---

## Prinsip desain

1. **Graph first** — satu model terpusat; output Markdown adalah consumer.
2. **Deterministik** — skor confidence berbasis bukti, bukan tebakan model AI.
3. **Tanpa opini arsitektur** — tidak memaksakan Clean Architecture; mendeteksi pola yang ada.
4. **Local-first** — semua analisis di mesin pengembang; tidak ada upload kode.
5. **Incremental** — `sync` hanya memproses file yang berubah (+ dependen import).

---

## Workflow yang disarankan

```bash
# Pertama kali
dart run flutter_ai_context init

# Setelah mengedit kode
dart run flutter_ai_context sync

# Cek apakah konteks masih segar
dart run flutter_ai_context status    # FRESH atau STALE

# Full rebuild (upgrade schema / refactor besar)
dart run flutter_ai_context scan
```

`status` membandingkan hash file dengan cache. Jika **STALE**, jalankan `sync` — bukan `scan`, kecuali ada alasan khusus.

---

## Graph schema v1

Schema graph **dibekukan** untuk jalur rilis 1.0. Perubahan breaking (format ID, rename tipe) membutuhkan versi schema baru dan major release package.

Baca kontrak lengkapnya di **[GRAPH_SCHEMA_v1.md](GRAPH_SCHEMA_v1.md)**.

---

## Batasan saat ini

- Resolusi semantik memakai cache AST; ada fallback saat konteks SDK tidak lengkap.
- Deteksi routing mendukung pola umum (GoRouter, Navigator, AutoRoute) — routing sangat nested mungkin belum lengkap.
- Context pack dibatasi token budget; tidak semua file feature masuk pack.
- Doctor melengkapi `flutter analyze`, bukan penggantinya.

Untuk roadmap publik, lihat bagian Roadmap di [README](../README.md).
