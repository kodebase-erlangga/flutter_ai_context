# Project Knowledge Graph — Schema v1

Dokumen ini menjelaskan **bentuk data** yang disimpan `flutter_ai_context` setelah menganalisis proyek Flutter Anda.

Bukan panduan penggunaan CLI — untuk itu lihat [README](../README.md).  
Di sini fokusnya: *apa isi graph*, *di mana disimpan*, dan *aturan stabilitas* sampai rilis 1.0.

---

## Ringkasan

| | |
|---|---|
| **Versi schema** | `1` (konstanta `graphSchemaVersion` di `lib/src/graph/schema.dart`) |
| **Status** | Dibekukan untuk jalur rilis 0.6.x → 1.0.0 |
| **File cache** | `.ai/cache/project_graph.json` |
| **Penanda versi** | `.ai/cache/schema_version` (berisi angka `1`) |

Graph adalah **sumber kebenaran** proyek. File seperti `AGENTS.md`, `.ai/architecture.md`, dan context pack hanyalah *turunan* dari graph ini.

---

## Apa itu Project Knowledge Graph?

Setelah `init` atau `sync`, CLI membangun graph: kumpulan **node** (hal-hal di proyek) dan **edge** (hubungan antar hal itu).

Contoh sederhana — feature auth dengan Provider:

```text
feature:Auth
  └── file:lib/features/auth/auth_screen.dart
        └── class:lib/features/auth/auth_screen.dart#AuthScreen  (screen)
              ├── reads → class:...#AuthProvider  (provider)
              └── uses_service → class:...#AuthService  (service)
```

Di disk, bentuknya JSON:

```json
{
  "schemaVersion": 1,
  "nodes": [
    {
      "id": "feature:Auth",
      "type": "feature",
      "name": "Auth"
    },
    {
      "id": "class:lib/features/auth/auth_screen.dart#AuthScreen",
      "type": "screen",
      "name": "AuthScreen",
      "file": "lib/features/auth/auth_screen.dart",
      "confidence": 0.95
    }
  ],
  "edges": [
    {
      "from": "class:lib/features/auth/auth_screen.dart#AuthScreen",
      "to": "class:lib/features/auth/auth_provider.dart#AuthProvider",
      "type": "reads"
    }
  ]
}
```

Anda bisa membuka `project_graph.json` langsung untuk debugging — file ini sengaja dibuat terbaca manusia (pretty-printed).

---

## Bentuk file JSON

Setiap graph punya tiga bagian utama:

```json
{
  "schemaVersion": 1,
  "nodes": [ /* daftar node */ ],
  "edges": [ /* daftar edge */ ]
}
```

### Node — objek apa di proyek?

Setiap node minimal punya:

- **`id`** — pengenal stabil (tidak berubah selama simbol/file sama)
- **`type`** — jenis node (lihat daftar di bawah)
- **`name`** — nama simbol atau file

Opsional:

- **`file`** — path relatif dari root proyek
- **`confidence`** — seberapa yakin klasifikasi (0.0–1.0, default `1.0`)
- **`evidence`** — alasan klasifikasi (`description`, `weight`)
- **`metadata`** — data tambahan untuk inference / context pack

**Metadata yang sering muncul:**

| Key | Contoh nilai | Kegunaan |
|-----|--------------|----------|
| `stateManagementFramework` | `getx`, `riverpod` | Deteksi state management hybrid |
| `supertype`, `methods` | tipe & daftar method | Signature di context pack |
| `routePath`, `routeName` | `/login`, `loginRoute` | Deteksi routing |

### Edge — bagaimana node saling berhubungan?

Setiap edge punya:

- **`from`** — id node sumber
- **`to`** — id node tujuan
- **`type`** — jenis hubungan

Opsional: `confidence`, `evidence`.

---

## Jenis node

Nama di JSON (kolom *wire name*) bisa berbeda dari nama enum di kode Dart — itu normal.

### Struktur proyek

| Wire name | Artinya |
|-----------|---------|
| `project` | Root proyek |
| `package` | Dependensi Dart (dari pubspec) |
| `feature` | Modul / folder feature |
| `file` | File sumber `.dart` |

### UI & navigasi

| Wire name | Artinya |
|-----------|---------|
| `screen` | Screen, page, atau widget entry-point |
| `widget` | Widget reusable (bukan screen utama) |
| `route` | Definisi route (GoRouter, AutoRoute, dll.) |

### State management

| Wire name | Artinya |
|-----------|---------|
| `provider` | Provider / ChangeNotifier (bukan GetX controller) |
| `bloc` | Bloc |
| `cubit` | Cubit |
| `notifier` | Riverpod notifier **atau** GetX controller |

> **Catatan:** `notifier` dipakai untuk dua pola berbeda. Bedanya biasanya terlihat di `metadata.stateManagementFramework` atau path file (`controllers/` → sering GetX).

### Lapisan data & layanan

| Wire name | Artinya |
|-----------|---------|
| `service` | Service / use-case layer |
| `repository` | Repository / data access |
| `api_client` | HTTP client (Dio, Retrofit, dll.) |
| `model` | Model / DTO |
| `entity` | Domain entity |

### Lainnya

| Wire name | Artinya |
|-----------|---------|
| `class` | Kelas Dart umum (enum: `classNode`) |
| `function` | Fungsi top-level atau bernama |
| `test` | File atau suite test |
| `unknown` | Fallback bila belum terklasifikasi |

---

## Jenis edge

Edge menggambarkan *arah* hubungan: `from` → `to`.

### Struktur & organisasi

- **`contains`** — parent memuat child (feature → file, file → class)
- **`belongs_to_feature`** — simbol termasuk feature tertentu

### Kode & dependensi

- **`imports`** — import Dart
- **`depends_on`** — dependensi arsitektural
- **`calls`** — pemanggilan fungsi/method
- **`extends`** — class extends (wire name untuk `extendsType`)
- **`implements`** — class implements (wire name untuk `implementsType`)

### State & reaktivitas

- **`watches`** — reactive watch (mis. `context.watch`)
- **`reads`** — reactive read (mis. `context.read`, `ref.read`)

### Arsitektur aplikasi

- **`uses_service`** — UI/provider memakai service
- **`uses_model`** — class memakai model data
- **`navigates_to`** — navigasi antar screen
- **`maps_to_route`** — screen terhubung ke definisi route
- **`tests`** — test mencakup simbol produksi

---

## Aturan ID stabil

ID harus **konsisten** antar `sync` selama file/simbol tidak berubah. Ini yang memungkinkan incremental update.

| Jenis | Format | Contoh |
|-------|--------|--------|
| File | `file:<path_relatif>` | `file:lib/main.dart` |
| Class | `class:<path>#<NamaKelas>` | `class:lib/features/home/home_screen.dart#HomeScreen` |
| Feature | `feature:<nama_feature>` | `feature:Attendance` |

Path dinormalisasi (separator konsisten, relatif ke root proyek).

---

## Versi schema & cache

CLI membandingkan versi di dua tempat:

1. `.ai/cache/schema_version` — file teks berisi angka
2. `project_graph.json` → field `schemaVersion`

Jika tidak cocok dengan `graphSchemaVersion` saat ini (`1`):

- Cache dianggap **tidak valid**
- `sync` akan memperingatkan dan melakukan rebuild
- `scan` selalu membangun ulang dari awal

**Pesan tipikal:** *"Cache schema v0 is incompatible with v1. Running full rebuild..."*

Setelah upgrade package major, jalankan:

```bash
dart run flutter_ai_context scan
```

---

## Kebijakan perubahan (kontrak v1)

### Boleh tanpa bump major (tetap v1)

- Menambah jenis node atau edge **baru**
- Menambah key `metadata` opsional
- Menambah field opsional di node/edge

### Tidak boleh — butuh schema v2 + major release

- Mengganti atau menghapus wire name yang sudah dipakai
- Mengubah format ID stabil
- Menghapus tipe yang masih diproduksi graph lama

Intinya: **v1 additive-only**. Breaking change = versi graph baru + dokumentasi migrasi.

---

## Untuk siapa dokumen ini?

| Pembaca | Yang perlu dibaca |
|---------|-------------------|
| **Pengguna CLI** | Ringkasan + bagian versi cache — cukup tahu graph ada di `.ai/cache/` |
| **Kontributor** | Semua — terutama jenis node/edge dan aturan ID |
| **Integrator (MCP, plugin)** | Bentuk JSON, `schemaVersion`, kebijakan perubahan |

---

## Dokumen terkait

- [architecture.md](architecture.md) — alur pipeline internal
- [README.md](../README.md) — instalasi, `sync` / `status`, workflow harian
