# Qiraat CSV Import Guide

This document describes the CSV format required for the `qiraat:import_csv` rake task to successfully import Qiraat (variant Quran readings) data.

---

## Quick Start

```bash
# Run the importer
rake qiraat:import_csv[/path/to/your/file.csv]

# Clear all existing juncture data (use with caution!)
rake qiraat:clear_junctures
```

---

## CSV File Structure Overview

The CSV file is organized into **blocks**, where each block represents a single **juncture** (a point of variation in the Quran). Blocks are separated by header rows that identify the Surah and verse.

```
┌─────────────────────────────────────────────────────────────┐
│  BLOCK 1: Juncture Header + Readings + Explanations         │
├─────────────────────────────────────────────────────────────┤
│  BLOCK 2: Juncture Header + Readings + Explanations         │
├─────────────────────────────────────────────────────────────┤
│  BLOCK 3: ...                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Column Layout

The importer expects data in specific columns (0-indexed):

| Column | Index | Content                          | Required |
|--------|-------|----------------------------------|----------|
| A      | 0     | Juncture header OR empty         | Varies   |
| B      | 1     | Arabic text OR explanation text  | ✓        |
| C      | 2     | (Unused by importer)             | -        |
| D      | 3     | Transliteration                  | ✓        |
| E-G    | 4-6   | (Unused by importer)             | -        |
| H      | 7     | English translation              | Optional |

---

## Block Structure

### 1. Juncture Header Row (Required)

The **first row** of each block must contain the juncture identifier in **Column A**.

**Format:** `{SurahName} {VerseNumber}` or `{SurahName} {StartVerse}-{EndVerse}`

**All 114 Surahs are supported.** The importer accepts multiple spelling variants for each Surah name.

<details>
<summary><strong>Click to expand full list of supported Surah names</strong></summary>

| # | Primary Name | Accepted Variants |
|---|--------------|-------------------|
| 1 | Fatiha | Al-Fatiha, Al-Fatihah |
| 2 | Baqara | Al-Baqara, Al-Baqarah, Baqarah |
| 3 | Ali-Imran | Aal-Imran, Al-Imran, Imran |
| 4 | Nisa | An-Nisa, An-Nisa', Nisaa |
| 5 | Maidah | Al-Maidah, Al-Ma'idah, Ma'idah |
| 6 | Anam | Al-Anam, Al-An'am, An'am |
| 7 | Araf | Al-Araf, Al-A'raf, A'raf |
| 8 | Anfal | Al-Anfal |
| 9 | Tawba | At-Tawba, At-Tawbah, Tawbah, Bara |
| 10 | Yunus | |
| 11 | Hud | |
| 12 | Yusuf | |
| 13 | Raad | Ra'ad, Ar-Raad, Ar-Ra'd |
| 14 | Ibrahim | |
| 15 | Hijr | Al-Hijr |
| 16 | Nahl | An-Nahl |
| 17 | Isra | Al-Isra, Al-Isra', Bani Israil |
| 18 | Kahf | Al-Kahf |
| 19 | Maryam | |
| 20 | Taha | Ta-Ha |
| 21 | Anbiya | Al-Anbiya, Al-Anbiya' |
| 22 | Hajj | Al-Hajj |
| 23 | Muminun | Al-Muminun, Al-Mu'minun |
| 24 | Nur | An-Nur |
| 25 | Furqan | Al-Furqan |
| 26 | Shuara | Ash-Shuara, Ash-Shu'ara' |
| 27 | Naml | An-Naml |
| 28 | Qasas | Al-Qasas |
| 29 | Ankabut | Al-Ankabut |
| 30 | Rum | Ar-Rum |
| 31 | Luqman | |
| 32 | Sajda | As-Sajda, As-Sajdah |
| 33 | Ahzab | Al-Ahzab |
| 34 | Saba | Saba' |
| 35 | Fatir | |
| 36 | Ya-Sin | Yasin, Yaseen |
| 37 | Saffat | As-Saffat |
| 38 | Sad | |
| 39 | Zumar | Az-Zumar |
| 40 | Ghafir | Mumin, Al-Mumin |
| 41 | Fussilat | Ha-Mim |
| 42 | Shura | Ash-Shura |
| 43 | Zukhruf | Az-Zukhruf |
| 44 | Dukhan | Ad-Dukhan |
| 45 | Jathiya | Al-Jathiya, Al-Jathiyah |
| 46 | Ahqaf | Al-Ahqaf |
| 47 | Muhammad | |
| 48 | Fath | Al-Fath |
| 49 | Hujurat | Al-Hujurat |
| 50 | Qaf | |
| 51 | Dhariyat | Adh-Dhariyat |
| 52 | Tur | At-Tur |
| 53 | Najm | An-Najm |
| 54 | Qamar | Al-Qamar |
| 55 | Rahman | Ar-Rahman |
| 56 | Waqia | Al-Waqia, Al-Waqi'ah |
| 57 | Hadid | Al-Hadid |
| 58 | Mujadila | Al-Mujadila, Al-Mujadilah |
| 59 | Hashr | Al-Hashr |
| 60 | Mumtahana | Al-Mumtahana, Al-Mumtahanah |
| 61 | Saff | As-Saff |
| 62 | Jumua | Al-Jumua, Al-Jumu'ah |
| 63 | Munafiqun | Al-Munafiqun |
| 64 | Taghabun | At-Taghabun |
| 65 | Talaq | At-Talaq |
| 66 | Tahrim | At-Tahrim |
| 67 | Mulk | Al-Mulk |
| 68 | Qalam | Al-Qalam, Nun |
| 69 | Haqqa | Al-Haqqa, Al-Haqqah |
| 70 | Maarij | Al-Maarij, Al-Ma'arij |
| 71 | Nuh | |
| 72 | Jinn | Al-Jinn |
| 73 | Muzzammil | Al-Muzzammil |
| 74 | Muddaththir | Al-Muddaththir, Muddathir |
| 75 | Qiyama | Al-Qiyama, Al-Qiyamah |
| 76 | Insan | Al-Insan, Dahr |
| 77 | Mursalat | Al-Mursalat |
| 78 | Naba | An-Naba, An-Naba' |
| 79 | Naziat | An-Naziat, An-Nazi'at |
| 80 | Abasa | |
| 81 | Takwir | At-Takwir |
| 82 | Infitar | Al-Infitar |
| 83 | Mutaffifin | Al-Mutaffifin |
| 84 | Inshiqaq | Al-Inshiqaq |
| 85 | Buruj | Al-Buruj |
| 86 | Tariq | At-Tariq |
| 87 | Ala | Al-Ala, Al-A'la |
| 88 | Ghashiya | Al-Ghashiya, Al-Ghashiyah |
| 89 | Fajr | Al-Fajr |
| 90 | Balad | Al-Balad |
| 91 | Shams | Ash-Shams |
| 92 | Layl | Al-Layl |
| 93 | Duha | Ad-Duha |
| 94 | Sharh | Ash-Sharh, Inshirah |
| 95 | Tin | At-Tin |
| 96 | Alaq | Al-Alaq |
| 97 | Qadr | Al-Qadr |
| 98 | Bayyina | Al-Bayyina, Al-Bayyinah |
| 99 | Zalzala | Az-Zalzala, Az-Zalzalah |
| 100 | Adiyat | Al-Adiyat |
| 101 | Qaria | Al-Qaria, Al-Qari'ah |
| 102 | Takathur | At-Takathur |
| 103 | Asr | Al-Asr |
| 104 | Humaza | Al-Humaza, Al-Humazah |
| 105 | Fil | Al-Fil |
| 106 | Quraysh | Quraish |
| 107 | Maun | Al-Maun, Al-Ma'un |
| 108 | Kawthar | Al-Kawthar, Kauthar |
| 109 | Kafirun | Al-Kafirun |
| 110 | Nasr | An-Nasr |
| 111 | Masad | Al-Masad, Lahab |
| 112 | Ikhlas | Al-Ikhlas |
| 113 | Falaq | Al-Falaq |
| 114 | Nas | An-Nas |

</details>

**Examples:**
```csv
Yunus 35,,,,...
Hijr 8,,,,...
Anfal 41-42,,,,...
```

> **💡 Tip:** Use any spelling variant from the table above. The importer is case-sensitive, so ensure the first letter is capitalized.

---

### 2. Base Text Row (Optional but Recommended)

The **second row** should contain the Arabic **base text** (the word(s) where the variation occurs) in **Column A**.

This text is used to locate the exact word position(s) in the verse.

**Examples:**
```csv
,يهدي,,,,...          # Single word
,اتوني...اتوني,,,,...  # Multi-segment (cross-verse or repeated)
,وإن ىكن…فإن ىكن,,,,...  # Multi-segment with ellipsis
```

**Multi-Segment Syntax:**
- Use `...` (three dots) or `…` (ellipsis character) to separate multiple segments
- Each segment will be matched independently in the verse(s)
- Useful for junctures that span multiple words or appear in different verses

> **Note:** If no base text is provided, the importer will attempt to use the first reading's Arabic text to locate word positions.

---

### 3. Reading Rows (Required)

Each reading variant is defined by a row with:

| Column A | Column B      | Column D          | Column H           |
|----------|---------------|-------------------|--------------------|
| Empty    | Arabic text   | Transliteration   | Translation (opt.) |

**Detection Rules:**
- Column A must be **empty**
- Column B must contain **Arabic characters** (Unicode range `\u0600-\u06FF`)
- Column D must contain **Latin characters** (transliteration)

**Example:**
```csv
,يَهدي,,...,yahdī,...,"who guides"
,يُهدى,,...,yuhdā,...,"who is guided"
,يَهِدِّي,,...,yahiddī,...,"who can guide"
```

---

### 4. Explanation Rows (Optional)

Explanations for individual readings are placed **immediately after** the reading row they belong to.

**Detection Rules:**
- Column A must be **empty**
- Column B must contain **text** (non-Arabic, English explanation)
- Column D must be **empty**
- Must NOT match "combined explanation" patterns (see below)

**Example:**
```csv
,يَهدي,,...,yahdī,...,"who guides"
,This reading emphasizes active guidance...,,,,...
,يُهدى,,...,yuhdā,...,"who is guided"
,This reading emphasizes passive reception...,,,,...
```

> **Note:** Multi-line explanations are concatenated with spaces.

---

### 5. Combined Explanation Row (Optional)

A combined explanation applies to **all readings** in the juncture. Place it anywhere in the block.

**Detection:** The importer looks for these keywords in Column B:
- "These readings"
- "Combined translation"
- "complementary meanings"
- "identical in meaning"
- "linguistic options"
- "amount to the same"
- "provide complementary"

**Example:**
```csv
,These readings are complementary and provide different theological perspectives on guidance.,,,,...
```

---

### 6. Attribution Matrix Rows (Optional)

The first 5 rows of each block can contain reader/transmitter names to indicate which readers use which reading.

**Recognized Reader Abbreviations:**
- `Ibn ʿĀmir`, `Ḥamzah`, `Khalaf`, `al-Kisāʾī`, `ʿĀṣim`
- `Abū Jaʿfar`, `Nāfiʿ`, `Ibn Kathīr`, `Abū ʿAmr`, `Yaʿqūb`

**Recognized Transmitter Abbreviations:**
- `Shuʿbah`, `Ḥafṣ`, `al-Bazzī`, `Qunbul`, `Qālūn`, `Warsh`

> **⚠️ Limitation:** CSV format cannot preserve cell colors from Excel. Reader attributions may need manual review after import.

---

## Shared Translations

The importer automatically handles **shared translations** between readings:

**Rule:** Readings WITHOUT a translation share the translation from the **immediately preceding** reading that HAS a translation.

**Example:**
```csv
# Reading 1 - has translation
,يَهدي,,...,yahdī,...,"who guides"

# Reading 2 - has translation
,يُهدى,,...,yuhdā,...,"who is guided"

# Reading 3 - has translation (becomes source for Reading 4)
,يَهِدِّي,,...,yahiddī,...,"who can guide"

# Reading 4 - NO translation (shares with Reading 3)
,يَهِدِّيّ,,...,yahiddiyy,...,
```

**Result:** Readings 3 and 4 will share the translation "who can guide"

---

## Word Position Matching

The importer uses **fuzzy Arabic matching** to locate words in verses:

### Normalization Applied:
1. Removes harakat (diacritics): `ـَ ـِ ـُ ـً ـٍ ـٌ ـّ ـْ`
2. Removes hamza markers
3. Normalizes alef variants: `إ أ آ ٱ` → `ا`
4. Normalizes ya: `ى` → `ي`
5. Removes spaces

### Matching Priority:
1. **Exact match** (after normalization) - highest priority
2. **Contained match** - search text found within verse word(s)
3. **Fuzzy match** - >50% character overlap

### Match Length:
- Tries 1, 2, then 3 consecutive words
- Prefers shorter matches (single word over multi-word)

---

## Complete Example Block

```csv
Yunus 35,,,,,,,
,يهدي,,,,,,,
,Ibn ʿĀmir,Ḥamzah,Khalaf,al-Kisāʾī,ʿĀṣim,Abū Jaʿfar,Nāfiʿ,Ibn Kathīr
,يَهدِي,,,yahdī,,,,"who cannot go the right way unless God guides him"
,This reading uses the active voice emphasizing God's role in guidance.,,,,,,,
,يُهْدَى,,,yuhdā,,,,"who cannot guide himself"
,This reading uses the passive voice emphasizing the seeker's state.,,,,,,,
,يَهَدِّي,,,yahaddī,,,,"who cannot guide at all"
,These readings provide complementary perspectives on the nature of divine guidance.,,,,,,,
```

---

## Troubleshooting

### Common Issues

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "Could not find verses, skipping" | Surah name not recognized | Check spelling matches SURAH_MAP |
| "Could not find word positions" | Arabic text not found in verse | Verify Arabic text matches Uthmani script |
| "Attributions could not be inferred" | CSV lacks color data | Manual attribution review needed |

### Validation Checklist

- [ ] File encoding is **UTF-8**
- [ ] Surah names match the supported list exactly
- [ ] Each block starts with a header row (Surah + Verse)
- [ ] Reading rows have Arabic in Column B, transliteration in Column D
- [ ] Arabic text uses proper Unicode (not images or special fonts)
- [ ] No merged cells (CSV doesn't support merging)

### Debug Output

The importer provides detailed console output:

```
============================================================
Importing: Yunus 35
  Base text: يهدي
============================================================
  Found verse(s): 10:35
  Found 3 reading(s)
  Found word positions: 35:5-5
  ✓ Created 1 segment(s)
  ✓ Reading 1: يَهدِي
  ✓ Reading 2: يُهْدَى
  ✓ Reading 3: يَهَدِّي
  ✓ Created shared translation for readings 2, 3
✅ Imported Yunus 35 with 3 readings
```

---

## Data Model Reference

The importer creates these database records:

| Model | Description |
|-------|-------------|
| `QiraatJuncture` | The point of variation |
| `QiraatJunctureSegment` | Links juncture to specific word(s) in verse(s) |
| `QiraatReading` | Each variant reading |
| `QiraatReadingAttribution` | Links reading to reader(s) |
| `QiraatReadingTranslation` | Shared translations |
| `QiraatReadingTranslationMembership` | Links readings to shared translations |
| `QiraatReadingExplanation` | Explanations for readings |
| `QiraatReadingExplanationMembership` | Links readings to explanations |
| `LocalizedContent` | All localized text (translations, transliterations, explanations) |

See [qiraat_data_model.md](./qiraat_data_model.md) for the complete schema.

---

## Adding New Spelling Variants

All 114 Surahs are already supported. To add a new spelling variant for an existing Surah, update the `SURAH_MAP` constant in `lib/tasks/qiraat_csv_import.rake`:

```ruby
SURAH_MAP = {
  # ... existing entries ...
  'NewVariant' => chapter_number,  # Add your variant here
}.freeze
```

---

## Version History

| Date | Change |
|------|--------|
| 2024-12 | Initial documentation created |
