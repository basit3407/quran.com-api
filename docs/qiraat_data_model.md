# Qirāʾāt Data Model

## Overview

This document defines the data model for displaying Qirāʾāt (variant Quran readings) information. The model captures:

- The 10 canonical Readers (Qurrāʾ) and their Transmitters (Rāwīs)
- Reading variations at specific word/phrase junctures
- Translations, transliterations, and explanations
- Relationships between readings (identical, complementary, etc.)

---

## Design Principles

> **Important:** This schema follows existing patterns in the codebase:

> - **Names** → Uses `name_translations` JSONB cache for fast reads
> - **Long content** → Uses polymorphic `localized_contents` table
> - **No `_en`, `_ar` suffixes** → All translations stored in language-aware tables
> - **Performance** → JSONB cache columns for frequently-accessed localized names
> - **Future-proof** → Single `localized_contents` table handles all localized content types

---

## Database Schema

### 1. `localized_contents` - Unified Polymorphic Content Table

A general-purpose, future-proof table for all localized content. This replaces the pattern of creating separate `*_infos` tables for each resource type.

| Field               | Type      | Required | Description                                              |
| ------------------- | --------- | -------- | -------------------------------------------------------- |
| id                  | PK        | ✓        | Auto-increment                                           |
| resource_type       | string    | ✓        | Polymorphic type: "QiraatReader", "QiraatReading", etc.  |
| resource_id         | integer   | ✓        | FK to the resource                                       |
| language_id         | FK        | ✓        | References `languages`                                   |
| content_type        | string    | ✓        | Discriminator: "bio", "explanation", "translation", etc. |
| text                | text      |          | Main content body                                        |
| short_text          | text      |          | Summary/excerpt (optional)                               |
| metadata            | jsonb     |          | Flexible key-value store for type-specific fields        |
| source              | string    |          | Attribution (e.g., "al-Alusi", "Ibn Ashur")              |
| resource_content_id | FK        |          | References `resource_contents` for approval workflow     |
| language_name       | string    |          | Denormalized for convenience                             |
| position            | integer   |          | Ordering for multiple entries of same type (default: 0)  |
| created_at          | timestamp | ✓        |                                                          |
| updated_at          | timestamp | ✓        |                                                          |

**Unique Constraint:** `(resource_type, resource_id, language_id, content_type, position)`

**Indexes:**

- `(resource_type, resource_id)` — polymorphic lookup
- `(resource_type, resource_id, language_id)` — language-filtered queries
- `(resource_type, resource_id, language_id, content_type)` — specific content lookup
- `language_id`
- `content_type`

**Content Types:**

| content_type           | Used By                                                 | Description                                  |
| ---------------------- | ------------------------------------------------------- | -------------------------------------------- |
| `bio`                  | QiraatReader, QiraatTransmitter                         | Biographical information                     |
| `translation`          | QiraatReadingTranslation, QiraatReading                 | Localized translation of the reading         |
| `transliteration`      | QiraatReading                                           | Academic transliteration                     |
| `explanation`          | QiraatReading, QiraatReadingExplanation, QiraatJuncture | Scholarly explanation (individual or shared) |
| `notes`                | QiraatReading                                           | Footnotes/additional notes                   |
| `combined_translation` | QiraatJuncture                                          | Unified translation for all readings         |

---

### 2. `qiraat_readers` - The 10 Canonical Readers

Stores information about each of the 10 Qurrāʾ (Readers).

| Field                | Type      | Required | Description                               |
| -------------------- | --------- | -------- | ----------------------------------------- |
| id                   | PK        | ✓        | Auto-increment                            |
| name                 | string    | ✓        | Default name, e.g., "Asim"                |
| abbreviation         | string    | ✓        | CSV key, e.g., "A" (unique)               |
| death_year_hijri     | integer   |          | e.g., 127                                 |
| death_year_gregorian | integer   |          | e.g., 745                                 |
| position             | integer   | ✓        | Display order (1-10)                      |
| name_translations    | jsonb     |          | Cached names: `{"en":"Asim","ar":"عاصم"}` |
| created_at           | timestamp | ✓        |                                           |
| updated_at           | timestamp | ✓        |                                           |

**Localization:**

- `localized_contents` → Biographical info (`content_type: 'bio'`)
- `name_translations` → JSONB cache for fast API reads

**Indexes:**

- `abbreviation` (unique)
- `position`

---

### 3. `qiraat_transmitters` - The Rāwīs (Transmitters)

Stores information about each transmitter who narrated from a Reader.

| Field                | Type      | Required | Description                              |
| -------------------- | --------- | -------- | ---------------------------------------- |
| id                   | PK        | ✓        | Auto-increment                           |
| qiraat_reader_id     | FK        | ✓        | References `qiraat_readers`              |
| name                 | string    | ✓        | Default name, e.g., "Hafs"               |
| abbreviation         | string    | ✓        | CSV key, e.g., "H", "S", "Q", "W"        |
| death_year_hijri     | integer   |          |                                          |
| death_year_gregorian | integer   |          |                                          |
| position             | integer   | ✓        | Order under the reader                   |
| is_primary           | boolean   |          | Primary transmitter (default: false)     |
| name_translations    | jsonb     |          | Cached names: `{"en":"Hafs","ar":"حفص"}` |
| created_at           | timestamp | ✓        |                                          |
| updated_at           | timestamp | ✓        |                                          |

**Localization:**

- `localized_contents` → Biographical info (`content_type: 'bio'`)
- `name_translations` → JSONB cache for fast API reads

**Indexes:**

- `qiraat_reader_id`
- `(qiraat_reader_id, position)`
- `abbreviation`

---

### 4. `qiraat_junctures` - Points of Variation

Stores each location where readings differ (the "juncture" or موضع). Word references are stored in `qiraat_juncture_segments`.

| Field       | Type      | Required | Description                                                                                                   |
| ----------- | --------- | -------- | ------------------------------------------------------------------------------------------------------------- |
| id          | PK        | ✓        | Auto-increment                                                                                                |
| juz_number  | integer   |          | Denormalized for filtering                                                                                    |
| hizb_number | integer   |          | Denormalized for filtering                                                                                    |
| position    | integer   | ✓        | Order (default: 0)                                                                                            |
| approved    | boolean   | ✓        | Whether juncture is visible in public APIs (default: false)                                                   |
| category    | string    |          | Classification: `A` (Meaning), `B` (Orthographic), `C` (Phonetic)                                             |
| flags       | string[]  |          | Tags: `grammatical`, `phonetic`, `morphological`, `semantic`, `dialectal`, `orthographic`, `recitation_style` |
| created_at  | timestamp | ✓        |                                                                                                               |
| updated_at  | timestamp | ✓        |                                                                                                               |

> **Note:** All verse/word references and text are stored in `qiraat_juncture_segments` and derived dynamically.

**Derived Properties (from segments):**

- `juncture_text_uthmani` — Combined Arabic text from all segments
- `juncture_text_imlaei` — Imlaei version
- `verse_key` — Computed from first/last segment (e.g., "8:65-66" for cross-verse)
- `verse_range` — Human-readable range (e.g., "8:65-66")
- `cross_verse?` — `true` if segments span multiple verses
- `primary_verse` — First segment's verse
- `all_words` — Aggregated Word objects from all segments

**Localization via `localized_contents`:**

- `content_type: 'combined_translation'` → Unified translation for all readings
- `content_type: 'explanation'` → Juncture-level explanation/commentary

---

### 5. `qiraat_juncture_segments` - Word References

Stores word ranges for each segment of a juncture. Supports cross-verse junctures.

| Field              | Type      | Required | Description                                   |
| ------------------ | --------- | -------- | --------------------------------------------- |
| id                 | PK        | ✓        | Auto-increment                                |
| qiraat_juncture_id | FK        | ✓        | References `qiraat_junctures`                 |
| verse_id           | FK        | ✓        | References `verses`                           |
| start_word_id      | FK        | ✓        | References `words` (first word in segment)    |
| end_word_id        | FK        | ✓        | References `words` (last word in segment)     |
| position           | integer   | ✓        | Order of segment within juncture (0, 1, 2...) |
| verse_key          | string    |          | Denormalized (e.g., "8:65")                   |
| created_at         | timestamp | ✓        |                                               |
| updated_at         | timestamp | ✓        |                                               |

**Derived Properties:**

- `segment_text_uthmani` — Text derived from words (NOT stored)
- `segment_text_imlaei` — Imlaei text from words
- `words` — All Word objects from start to end

**Usage:**

- **Single-verse juncture:** 1 segment (e.g., Yunus 10:35, word 1-1)
- **Cross-verse juncture:** 2+ segments (e.g., Al-Anfal 8:65-66)

**Example: Al-Anfal 8:65-66 Cross-Verse Juncture**

```
Juncture ID: 1
├── Segment 0: Verse 8:65, words 1-2 (وَاِنْ يَّكُنْ)
└── Segment 1: Verse 8:66, words 1-2 (فاِنْ يَّكُنْ)
```

**Indexes:**

- `qiraat_juncture_id`
- `verse_id`
- `(qiraat_juncture_id, position)`

---

### 6. `qiraat_readings` - Individual Reading Variants

Stores each distinct reading variant for a juncture (language-neutral data only).

| Field              | Type      | Required | Description                                              |
| ------------------ | --------- | -------- | -------------------------------------------------------- |
| id                 | PK        | ✓        | Auto-increment                                           |
| qiraat_juncture_id | FK        | ✓        | References `qiraat_junctures`                            |
| text_uthmani       | string    | ✓        | Arabic text: "فَأَزَلَّهُمَا"                            |
| text_imlaei        | string    |          | Alternative script                                       |
| grammatical_form   | string    |          | e.g., "Form II", "Active Voice"                          |
| root_letters       | string    |          | e.g., "ز ل ل" or "ز و ل" (Arabic only)                   |
| position           | integer   | ✓        | Display order (1-indexed)                                |
| color              | string    |          | UI color for this reading (hex code, default: "#f5f5f5") |
| created_at         | timestamp | ✓        |                                                          |
| updated_at         | timestamp | ✓        |                                                          |

**Color Logic:**

Colors are assigned **per reading (variant) within a juncture**.

Key rule: **Everyone who shares the same reading shares the same background color**, regardless of lineage.

Example: If Ibn ʿĀmir, Abū Jaʿfar, Nāfiʿ, Ibn Kathīr, Abū ʿAmr, Yaʿqūb and **Ḥafṣ** all follow the same reading at this juncture, they all render with the same color (typically white/off‑white). If **Shuʿbah** differs and matches Ḥamzah/Khalaf/al‑Kisāʾī, those cells share the other reading's color (e.g., green).

**Splits (Reader vs. Transmitters):**

- If a Reader is **not split** at a juncture (reader-level attribution), the Reader's matrix cell uses the color of the attributed reading.
- If a Reader **is split** at a juncture (transmitter-level attributions exist), the Reader "parent" header is always rendered **gray** (not stored in the DB), while each transmitter's cell uses the color of its attributed reading.

**Localization via `localized_contents`:**

- `content_type: 'transliteration'` → Academic transliteration
- `content_type: 'notes'` → Footnotes/additional notes

> **Note:** Translations and explanations are stored via shared entities (`qiraat_reading_translations`, `qiraat_reading_explanations`) and linked via membership tables.

**Indexes:**

- `qiraat_juncture_id`
- `(qiraat_juncture_id, position)`

---

### 7. `qiraat_reading_attributions` - Unified Reader/Transmitter Join

Links readings to Readers and optionally specific Transmitters. This single table replaces separate reader/transmitter join tables.

| Field                 | Type      | Required | Description                                                            |
| --------------------- | --------- | -------- | ---------------------------------------------------------------------- |
| id                    | PK        | ✓        | Auto-increment                                                         |
| qiraat_reading_id     | FK        | ✓        | References `qiraat_readings`                                           |
| qiraat_reader_id      | FK        |          | References `qiraat_readers` (auto-derived from transmitter if not set) |
| qiraat_transmitter_id | FK        |          | NULL = all transmitters of this reader                                 |
| created_at            | timestamp | ✓        |                                                                        |
| updated_at            | timestamp | ✓        |                                                                        |

**Attribution Logic:**

- **Reader-level attribution** (transmitter_id = NULL, reader_id = X): Applies to ALL transmitters of reader X
- **Transmitter-level attribution** (transmitter_id = X): Attribution is for specific transmitter only. Reader is automatically derived from transmitter's `qiraat_reader_id`.

> **Note:** At least one of `qiraat_reader_id` or `qiraat_transmitter_id` must be present. If only transmitter is specified, the reader is automatically derived.

**Query Logic:**

- `WHERE qiraat_transmitter_id IS NULL` → Reader-level (applies to all transmitters)
- `WHERE qiraat_transmitter_id = X` → Transmitter-specific exception

**Examples:**

```ruby
# Reader-level: Nāfiʿ uses this reading (both Qālūn and Warsh)
{ reading_id: 1, reader_id: 1, transmitter_id: NULL }

# Transmitter-level split: Only Ḥafṣ from ʿĀṣim uses this reading
# reader_id is auto-derived from transmitter
{ reading_id: 2, reader_id: nil, transmitter_id: 10 }  # Ḥafṣ (transmitter 10 belongs to ʿĀṣim)
{ reading_id: 3, reader_id: nil, transmitter_id: 9 }   # Shuʿbah uses different
```

**Indexes:**

- `qiraat_reading_id`
- `qiraat_reader_id`
- `(qiraat_reading_id, qiraat_reader_id, qiraat_transmitter_id)` unique

---

### 8. `qiraat_reading_translations` - Shared Reading Translations

Stores shareable translations that can be linked to multiple readings. This supports the common case where multiple readings share the same semantic meaning and translation.

| Field      | Type      | Required | Description                               |
| ---------- | --------- | -------- | ----------------------------------------- |
| id         | PK        | ✓        | Auto-increment                            |
| source     | string    |          | Attribution (e.g., "Bridges Translation") |
| position   | integer   |          | Display order if multiple (default: 0)    |
| created_at | timestamp | ✓        |                                           |
| updated_at | timestamp | ✓        |                                           |

**Localization via `localized_contents`:**

- `content_type: 'translation'` → The localized translation text

**Indexes:**

- `source`
- `position`

---

### 9. `qiraat_reading_translation_memberships` - Reading ↔ Translation Join

Many-to-many join table linking readings to their shared translations.

| Field                         | Type      | Required | Description                              |
| ----------------------------- | --------- | -------- | ---------------------------------------- |
| id                            | PK        | ✓        | Auto-increment                           |
| qiraat_reading_id             | FK        | ✓        | References `qiraat_readings`             |
| qiraat_reading_translation_id | FK        | ✓        | References `qiraat_reading_translations` |
| created_at                    | timestamp | ✓        |                                          |
| updated_at                    | timestamp | ✓        |                                          |

**Unique Constraint:** `(qiraat_reading_id, qiraat_reading_translation_id)`

**Indexes:**

- `qiraat_reading_id`
- `qiraat_reading_translation_id`

---

### 10. `qiraat_reading_explanations` - Shared Reading Explanations

Stores shareable explanations that can be linked to multiple readings. This avoids data duplication when the same scholarly explanation applies to several reading variants.

| Field      | Type      | Required | Description                            |
| ---------- | --------- | -------- | -------------------------------------- |
| id         | PK        | ✓        | Auto-increment                         |
| source     | string    |          | Attribution (e.g., "al-Alusi")         |
| position   | integer   |          | Display order if multiple (default: 0) |
| created_at | timestamp | ✓        |                                        |
| updated_at | timestamp | ✓        |                                        |

**Localization via `localized_contents`:**

- `content_type: 'explanation'` → The localized explanation text

**Indexes:**

- `source`
- `position`

---

### 11. `qiraat_reading_explanation_memberships` - Reading ↔ Explanation Join

Many-to-many join table linking readings to their shared explanations.

| Field                         | Type      | Required | Description                              |
| ----------------------------- | --------- | -------- | ---------------------------------------- |
| id                            | PK        | ✓        | Auto-increment                           |
| qiraat_reading_id             | FK        | ✓        | References `qiraat_readings`             |
| qiraat_reading_explanation_id | FK        | ✓        | References `qiraat_reading_explanations` |
| created_at                    | timestamp | ✓        |                                          |
| updated_at                    | timestamp | ✓        |                                          |

**Unique Constraint:** `(qiraat_reading_id, qiraat_reading_explanation_id)`

**Indexes:**

- `qiraat_reading_id`
- `qiraat_reading_explanation_id`

---

## Entity Relationship Diagram

```text
                              ┌─────────────────────────┐
                              │   localized_contents    │
                              │   (polymorphic)         │
                              │   ─────────────────     │
                              │   resource_type         │
                              │   resource_id           │
                              │   language_id           │
                              │   content_type          │
                              │   text / short_text     │
                              │   metadata (JSONB)      │
                              └───────────┬─────────────┘
                                          │
        ┌──────────────────┬──────────────┼──────────────┬──────────────────┐
        │                  │              │              │                  │
        ▼                  ▼              ▼              ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌─────────────────────┐
│qiraat_readers │  │qiraat_reading_│  │qiraat_reading_│  │qiraat_transmitters │
│ (10 Qurrāʾ)   │  │ translations  │  │ explanations  │  │     (Rāwīs)        │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘  └────────────────────┘
        │                  │                  │                   ▲
        │                  │ N:M              │ N:M               │
        │                  ▼                  ▼                   │
        │          ┌───────────────────────────────────┐          │
        │          │   qiraat_reading_*_memberships    │          │
        │          │ (translation + explanation joins) │          │
        │          └───────────────┬───────────────────┘          │
        │                          │ N:M                          │
        │                          ▼                              │
        │              ┌─────────────────────┐                    │
        │              │  qiraat_readings    │◄───────────────────┤
        │              │  (variants)         │                    │
        │              └─────────┬───────────┘                    │
        │                        │ N:1                            │
        │                        ▼                                │
        │              ┌─────────────────────┐                    │
        │              │  qiraat_junctures   │                    │
        │              │  (points of diff)   │                    │
        │              └─────────┬───────────┘                    │
        │                        │ 1:N                            │
        │                        ▼                                │
        │              ┌──────────────────────────┐               │
        │              │qiraat_juncture_segments  │───────┐       │
        │              │ (word references)        │       │       │
        │              └──────────────────────────┘       ▼       │
        │                                          ┌──────────┐   │
        │    ┌─────────────────────────────────┐   │  verses  │   │
        │    │ qiraat_reading_attributions     │   │  words   │   │
        └───►│ (readings ↔ readers/transmitters)│   └──────────┘   │
             └─────────────────────────────────┘                   │
                            │                                      │
                            └──────────────────────────────────────┘
```

---

## Relationship Types

These classifications describe the semantic relationship between variant readings at a juncture:

| Type             | Arabic     | Description                                                         | Example                        |
| ---------------- | ---------- | ------------------------------------------------------------------- | ------------------------------ |
| `identical`      | متطابق     | Two linguistic options (dialects, pronunciation). Same meaning.     | Quds vs Qudus                  |
| `near_identical` | شبه متطابق | Same base meaning but different construction/grammar.               | fa-lā khawfa vs fa-lā khawfun  |
| `complementary`  | متكامل     | Two distinct but non-contradictory meanings. Both valid.            | mālik vs malik (Owner vs King) |
| `layered`        | متراكب     | Requires applying to different scenarios to reconcile.              | Requires taʾwīl                |
| `complex`        | مشكل       | Non-contradictory reading requires stretching apparent senses.      | Needs tarjīḥ or tawaqquf       |
| `contradictory`  | متناقض     | Readings that appear to conflict. Requires scholarly resolution.    | arjulakum vs arjulikum         |
| `criticized`     | منتقد      | Reading considered difficult by some scholars. Often has a defense. | bihī wa-l-arḥāmi               |

---

## Sample Data

### Readers (qiraat_readers)

| id  | abbreviation | name       | position |
| --- | ------------ | ---------- | -------- |
| 1   | N            | Nafi       | 1        |
| 2   | I            | Ibn Kathir | 2        |
| 3   | B            | Abu Amr    | 3        |
| 4   | M            | Ibn Amir   | 4        |
| 5   | A            | Asim       | 5        |
| 6   | Z            | Hamzah     | 6        |
| 7   | K            | al-Kisai   | 7        |
| 8   | J            | Abu Jafar  | 8        |
| 9   | Y            | Yaqub      | 9        |
| 10  | X            | Khalaf     | 10       |

> **Abbreviation Key:** N = Nāfiʿ, M = Ibn ʿĀmir, B = Abū ʿAmr (Basrah), I = Ibn Kathīr, A = ʿĀṣim, Z = Ḥamzah, K = al-Kisāʾī, J = Abū Jaʿfar, Y = Yaʿqūb, X = Khalaf

### Transmitters (qiraat_transmitters)

| id  | reader_id | abbreviation | name           | is_primary | position |
| --- | --------- | ------------ | -------------- | ---------- | -------- |
| 1   | 1         | Q            | Qālūn          | true       | 1        |
| 2   | 1         | W            | Warsh          | false      | 2        |
| 3   | 2         | M1           | al-Bazzī       | true       | 1        |
| 4   | 2         | M2           | Qunbul         | false      | 2        |
| 5   | 3         | B1           | al-Dūrī        | true       | 1        |
| 6   | 3         | B2           | al-Sūsī        | false      | 2        |
| 7   | 4         | I1           | Hishām         | true       | 1        |
| 8   | 4         | I2           | Ibn Dhakwān    | false      | 2        |
| 9   | 5         | S            | Shuʿbah        | true       | 1        |
| 10  | 5         | H            | Ḥafṣ           | false      | 2        |
| 11  | 6         | Z1           | Khalaf←Ḥamzah  | true       | 1        |
| 12  | 6         | Z2           | Khallād        | false      | 2        |
| 13  | 7         | K1           | Abū al-Ḥārith  | true       | 1        |
| 14  | 7         | K2           | al-Dūrī←Kisāʾī | false      | 2        |
| 15  | 8         | J1           | Ibn Wardān     | true       | 1        |
| 16  | 8         | J2           | Ibn Jammāz     | false      | 2        |
| 17  | 9         | Y1           | Ruways         | true       | 1        |
| 18  | 9         | Y2           | Rawḥ           | false      | 2        |
| 19  | 10        | X1           | Isḥāq          | true       | 1        |
| 20  | 10        | X2           | Idrīs          | false      | 2        |

> **Transmitter Abbreviation Key:**
>
> - N: Q = Qālūn, W = Warsh
> - M (Ibn Kathīr): M1 = al-Bazzī, M2 = Qunbul
> - B (Abū ʿAmr): B1 = al-Dūrī, B2 = al-Sūsī
> - I (Ibn ʿĀmir): I1 = Hishām, I2 = Ibn Dhakwān
> - A (ʿĀṣim): S = Shuʿbah, H = Ḥafṣ
> - Z (Ḥamzah): Z1 = Khalaf←Ḥamzah, Z2 = Khallād
> - K (al-Kisāʾī): K1 = Abū al-Ḥārith, K2 = al-Dūrī←Kisāʾī
> - J (Abū Jaʿfar): J1 = Ibn Wardān, J2 = Ibn Jammāz
> - Y (Yaʿqūb): Y1 = Ruways, Y2 = Rawḥ
> - X (Khalaf al-ʿĀshir): X1 = Isḥāq, X2 = Idrīs

---

## CSV Mapping Examples

### Example 1: Al-Fātiḥa 1:4 - Complementary Meanings (mālik vs malik)

**CSV Row:**

```json
{
  "ID": "1.4.1",
  "Juz": 1,
  "Surah": 1,
  "Ayah": 4,
  "Juncture #": 1,
  "Juncture": "ملك",
  "Reading 1 Reciters": "A K Y X",
  "Reading 1 (Arabic)": "مَالِكِ",
  "Translit 1": "māliki yawm al-dīn",
  "Translation 1": "\"Owner of the Day of Judgement\"",
  "Reading 2 Reciters": "N J M B I Z",
  "Reading 2 (Arabic)": "مَلِكِ",
  "Translit 2": "maliki yawm al-dīn",
  "Translation 2": "\"King of the Day of Judgement\"",
  "Commentary 1": "The first reading, with the alif (mālik), denotes ownership... The second reading (malik), denotes sovereignty..."
}
```

**Mapped to Tables:**

**qiraat_junctures:**

| id  | position | flags |
| --- | -------- | ----- |
| 1   | 1        | []    |

**qiraat_juncture_segments:**

| id  | juncture_id | verse_id | start_word_id | end_word_id | position | verse_key |
| --- | ----------- | -------- | ------------- | ----------- | -------- | --------- |
| 1   | 1           | 4        | 10            | 10          | 0        | 1:4       |

**qiraat_readings:**

| id  | juncture_id | text_uthmani | position | color   |
| --- | ----------- | ------------ | -------- | ------- |
| 1   | 1           | مَالِكِ      | 1        | #f5f5f5 |
| 2   | 1           | مَلِكِ       | 2        | #e8f5e9 |

**qiraat_reading_attributions:**

| reading_id | reader_id | transmitter_id | (Reader)       |
| ---------- | --------- | -------------- | -------------- |
| 1          | 5         | NULL           | A - ʿĀṣim      |
| 1          | 7         | NULL           | K - al-Kisāʾī  |
| 1          | 9         | NULL           | Y - Yaʿqūb     |
| 1          | 10        | NULL           | X - Khalaf     |
| 2          | 1         | NULL           | N - Nāfiʿ      |
| 2          | 8         | NULL           | J - Abū Jaʿfar |
| 2          | 4         | NULL           | M - Ibn ʿĀmir  |
| 2          | 3         | NULL           | B - Abū ʿAmr   |
| 2          | 2         | NULL           | I - Ibn Kathīr |
| 2          | 6         | NULL           | Z - Ḥamzah     |

---

### Example 2: Transmitter-Level Split (ʿĀṣim split)

**Scenario:** ʿĀṣim → Shuʿbah reads تَسْتَوِي, Ḥafṣ reads يَسْتَوِي

**qiraat_reading_attributions:**

| reading_id | reader_id | transmitter_id | Notes                  |
| ---------- | --------- | -------------- | ---------------------- |
| 10         | 5         | 9              | ʿĀṣim via Shuʿbah only |
| 11         | 5         | 10             | ʿĀṣim via Ḥafṣ only    |

---

### Example 3: Cross-Verse Juncture (Al-Anfal 8:65-66)

**Scenario:** Juncture spans two verses with different readings across matching positions.

**qiraat_juncture_segments:**

| id  | juncture_id | verse_id | start_word_id | end_word_id | position | verse_key |
| --- | ----------- | -------- | ------------- | ----------- | -------- | --------- |
| 1   | 5           | 1242     | 8650          | 8652        | 0        | 8:65      |
| 2   | 5           | 1243     | 8660          | 8662        | 1        | 8:66      |

**Result:** `juncture.verse_key` returns "8:65-66", `juncture.cross_verse?` returns `true`

---

## API Response Example

```json
{
  "verse_key": "2:36",
  "junctures": [
    {
      "id": 1,
      "position": 1,
      "text_uthmani": "فَأَزَلَّهُمَا",
      "segments": [
        {
          "verse_key": "2:36",
          "start_word_position": 1,
          "end_word_position": 1,
          "text_uthmani": "فَأَزَلَّهُمَا"
        }
      ],
      "readings": [
        {
          "id": 1,
          "text_uthmani": "فَأَزَلَّهُمَا",
          "root_letters": "ز ل ل",
          "transliteration": "fa-azallahumā",
          "translation": "Then he caused them to err",
          "color": "#f5f5f5",
          "readers": [
            { "id": 1, "abbreviation": "N", "name": "Nāfiʿ" },
            { "id": 4, "abbreviation": "M", "name": "Ibn ʿĀmir" }
          ]
        },
        {
          "id": 2,
          "text_uthmani": "فَأَزَالَهُمَا",
          "root_letters": "ز و ل",
          "transliteration": "fa-azālahumā",
          "translation": "Then he caused them to be removed",
          "color": "#e8f5e9",
          "readers": [{ "id": 6, "abbreviation": "Z", "name": "Ḥamzah" }]
        }
      ],
      "explanation": {
        "text": "The readings are equivalent if both are taken to refer to how Satan removed them from their secure position...",
        "source": "al-Alusi"
      }
    }
  ]
}
```

---

## Tables Summary

| #   | Table                                    | Purpose                                                                                       |
| --- | ---------------------------------------- | --------------------------------------------------------------------------------------------- |
| 1   | `localized_contents`                     | **Unified polymorphic table** for all localized content (bio, translation, explanation, etc.) |
| 2   | `qiraat_readers`                         | The 10 canonical Qurrāʾ                                                                       |
| 3   | `qiraat_transmitters`                    | Rāwīs who narrated from readers                                                               |
| 4   | `qiraat_junctures`                       | Points of variation (metadata only, no word refs)                                             |
| 5   | `qiraat_juncture_segments`               | Word references for junctures (supports cross-verse)                                          |
| 6   | `qiraat_readings`                        | Individual reading variants                                                                   |
| 7   | `qiraat_reading_attributions`            | Unified join: readings ↔ readers/transmitters                                                 |
| 8   | `qiraat_reading_translations`            | **Shareable localized translations** for readings                                             |
| 9   | `qiraat_reading_translation_memberships` | N:M join: readings ↔ translations                                                             |
| 10  | `qiraat_reading_explanations`            | **Shareable explanations** for readings                                                       |
| 11  | `qiraat_reading_explanation_memberships` | N:M join: readings ↔ explanations                                                             |

**Total: 11 tables**

### Content Types in `localized_contents`

| content_type           | Resource Types                           | Fields Used                        |
| ---------------------- | ---------------------------------------- | ---------------------------------- |
| `bio`                  | QiraatReader, QiraatTransmitter          | `text`, `metadata: {city, region}` |
| `translation`          | QiraatReadingTranslation                 | `text`                             |
| `transliteration`      | QiraatReading                            | `text`                             |
| `explanation`          | QiraatReadingExplanation, QiraatJuncture | `text`, `source`                   |
| `combined_translation` | QiraatJuncture                           | `text`                             |
| `notes`                | QiraatReading                            | `text`                             |
