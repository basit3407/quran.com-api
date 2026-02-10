# Layered Translations Implementation Spec (As Implemented)

## 1) Product Scope

Layered Translations adds a Study Mode content type where each ayah has:

- A collapsed translation form.
- An expanded translation form.
- Inline alternative translation groups that can be switched by the user.
- Group-level explanation content.
- Footnotes with standard translation-like footnote interaction.

This implementation is language-separated by resource (not one multi-language resource).

## 2) Product Behavior

For a given verse and resource:

- The API returns both `collapsed_template` and `expanded_template`.
- Each template includes group tokens in the format `{{g:group_key}}`.
- Each `group_key` maps to a set of options (`option_key`) with:
  - `collapsed_html`
  - `expanded_html`
- Each group has one `default_option_key`.
- Group-level optional explanation is returned as `explanation_html`.
- Footnote references are embedded in HTML as `<sup foot_note="ID">N</sup>`.

No `ui` object is stored in DB or returned by API.

## 3) Canonical Resource Flag

Layered translation resources are identified by:

- `resource_contents.sub_type = 'translation'`
- `resource_contents.cardinality_type = '1_ayah'`
- `resource_contents.approved = true`
- `resource_contents.permission_to_share != rejected`
- `resource_contents.meta_data ->> 'is-layered-translation' = 'true'`

Note: the canonical metadata key used in API scope is `is-layered-translation`.

## 4) Database Schema

Implemented via migration:

- `db/migrate/20260206100000_create_layered_translation_structures.rb`

### 4.1 `layered_translation_ayahs`

Purpose: one record per `(resource_content_id, verse_id)`.

Columns:

- `id` (bigint, PK)
- `resource_content_id` (int, FK -> `resource_contents.id`, required)
- `verse_id` (int, FK -> `verses.id`, required)
- `collapsed_template` (text, required)
- `expanded_template` (text, required)
- `created_at`, `updated_at`

Indexes:

- Unique: `(resource_content_id, verse_id)` as `idx_layered_translation_ayahs_on_resource_and_verse`
- `resource_content_id`
- `verse_id`

### 4.2 `layered_translation_groups`

Purpose: inline alternative group definitions per ayah.

Columns:

- `id` (bigint, PK)
- `layered_translation_ayah_id` (bigint, FK, required)
- `group_key` (string, required)
- `position` (int, required, default `1`)
- `default_option_key` (string, required)
- `explanation_html` (text, optional)
- `created_at`, `updated_at`

Indexes:

- Unique: `(layered_translation_ayah_id, group_key)` as `idx_layered_translation_groups_on_ayah_and_key`
- `layered_translation_ayah_id`

### 4.3 `layered_translation_options`

Purpose: option variants inside a group.

Columns:

- `id` (bigint, PK)
- `layered_translation_group_id` (bigint, FK, required)
- `option_key` (string, required)
- `position` (int, required, default `1`)
- `collapsed_html` (text, required)
- `expanded_html` (text, required)
- `created_at`, `updated_at`

Indexes:

- Unique: `(layered_translation_group_id, option_key)` as `idx_layered_translation_options_on_group_and_key`
- `layered_translation_group_id` as `idx_lt_options_on_group`

### 4.4 `foot_notes` extension

Purpose: allow layered translation footnotes without changing standard translation footnotes.

Added column:

- `layered_translation_ayah_id` (bigint, nullable, FK -> `layered_translation_ayahs.id`)

Existing `foot_notes.translation_id` remains unchanged for standard translation footnotes.

## 5) Domain Model Rules

### 5.1 `LayeredTranslationAyah`

- Requires non-empty collapsed and expanded templates.
- Enforces uniqueness per `(resource_content_id, verse_id)`.
- Extracts tokenized templates via `TOKEN_PATTERN = /\{\{\s*g:([A-Za-z0-9_-]+)\s*\}\}/`.
- Validates templates do not reference missing `group_key` values (when groups exist).

### 5.2 `LayeredTranslationGroup`

- Requires `group_key`, `default_option_key`, `position > 0`.
- `group_key` unique per ayah.
- Validates `default_option_key` exists among the group's options.

### 5.3 `LayeredTranslationOption`

- Requires `option_key`, `collapsed_html`, `expanded_html`, `position > 0`.
- `option_key` unique per group.

## 6) API Contract

Routes:

- `GET /api/qdc/layered_translations/by_verse/:verse_key`
- `GET /api/qdc/layered_translations/count_within_range?from=:verse_key&to=:verse_key`

Defined in:

- `config/routes/api/qdc.rb`
- `app/controllers/api/qdc/layered_translations_controller.rb`

### 6.1 `GET by_verse`

Query params:

- `verse_key` (path, required): `chapter:verse`
- `resource_id` (optional): explicit resource to use
- `language` (optional, default `en`): preferred language when `resource_id` is not passed

Resource resolution:

1. If `resource_id` present, use that layered resource.
2. Else try layered resource in requested language.
3. Else fallback to English layered resource.

Success shape (streamed JSON):

- `verse`
  - `verse_key`
  - `chapter_number`
  - `verse_number`
- `resource`
  - `id`
  - `name`
  - `language`
- `collapsed_template`
- `expanded_template`
- `collapsed_tokens[]`
  - `{ type: 'text', html }` or `{ type: 'alt_group', group_key }`
- `expanded_tokens[]`
  - `{ type: 'text', html }` or `{ type: 'alt_group', group_key }`
- `groups[]`
  - `group_key`
  - `position`
  - `default_option_key`
  - `explanation_html`
  - `options[]`
    - `option_key`
    - `position`
    - `collapsed_html`
    - `expanded_html`
- `meta`
  - `requested_language`
  - `resolved_language`
  - `fallback_used`
  - `generated_at`

Error response:

- HTTP `400` for invalid params with code `INVALID_PARAMETER`
- HTTP `404` when verse/resource/layered data is missing with code `NOT_FOUND`

### 6.2 `GET count_within_range`

Query params:

- `from` (required): `chapter:verse`
- `to` (required): `chapter:verse`
- `resource_id` (optional)
- `language` (optional, default `en`)

Response:

- Object keyed by `verse_key`, value `0` or `1` (presence bit within range).
- Returns `{}` if no layered resource is resolved.

## 7) Frontend Rendering Contract (API Consumer)

The intended frontend flow is:

1. Use `count_within_range` to show tab availability by verse range.
2. Use `by_verse` to fetch ayah payload.
3. Render collapsed/expanded template by replacing each `alt_group` token with currently selected option text for that group.
4. On group interaction, show selectable options and render selected option's explanation.
5. Footnote behavior uses existing footnote UX against embedded `<sup foot_note="ID">N</sup>`.

## 8) Content Ingestion and Admin Flow (Implemented Across Tools + API)

Admin/import behavior (implemented in `tools.quran.com`, persisted to this API DB):

- Source supports `.docx` and `.csv` uploads.
- DOCX is converted to layered CSV using `layered_translation_doc_pdf_to_csv.py`.
- CSV is validated and imported into layered translation tables and `foot_notes`.
- Matrix editor supports:
  - editing templates, groups, options, footnotes
  - TinyMCE helper menus for `Footnote` insertion/update
  - TinyMCE helper menu for `Group` token insertion/update in templates

Current conversion decisions:

- Group explanation is sourced from variation explanation only.
- General ayah explanation is not auto-fallback into group explanation.
- For verses with no real variation groups, no automatic group explanation fallback is written.

## 9) Explicit Non-Goals in This Implementation

- No cross-language merged resource payload.
- No API `ui` configuration object.
- No FE state persistence in API.

## 10) Key Implementation Files

API:

- `app/controllers/api/qdc/layered_translations_controller.rb`
- `app/views/api/qdc/layered_translations/by_verse.json.streamer`
- `app/views/api/qdc/layered_translations/count_within_range.json.streamer`
- `app/models/layered_translation_ayah.rb`
- `app/models/layered_translation_group.rb`
- `app/models/layered_translation_option.rb`
- `app/models/foot_note.rb`
- `app/models/resource_content.rb`
- `db/migrate/20260206100000_create_layered_translation_structures.rb`
- `db/migrate/20260207110000_remove_layered_translation_group_dependencies.rb`
- `db/schema.rb`

Cross-repo tooling (authoring/import/editor):

- `tools.quran.com/app/services/csv_layered_translation_importer.rb`
- `tools.quran.com/app/services/layered_translation_source_to_csv_converter.rb`
- `tools.quran.com/scripts/layered_translation_doc_pdf_to_csv.py`
- `tools.quran.com/app/controllers/layered_translation_imports_controller.rb`
- `tools.quran.com/app/controllers/layered_translations/matrix_controller.rb`
- `tools.quran.com/app/views/layered_translations/matrix/show.html.erb`
- `tools.quran.com/app/javascript/controllers/tinymce_controller.js`
