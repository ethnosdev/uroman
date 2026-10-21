# uroman

A Dart port of the **Universal Romanizer (uroman)**.

Converts text in virtually any writing system into the Latin alphabet. Although designed for high fidelity with upstream Python [uroman](https://github.com/isi-nlp/uroman), it diverges to incorporate fixes for known upstream bugs and data typos.

## Features

- **Broad Script Coverage**: Supports Latin, Cyrillic, Greek, Arabic, Hebrew, Devanagari, Bengali, Tamil, Thai, Tibetan, Georgian, Amharic, Hangul, CJK ideographs, Klingon, Braille, Egyptian hieroglyphs, and many more.
- **Pure Dart**: Zero runtime dependencies in core library. Only `package:args` is used for the CLI binary.
- **Web & WASM Ready**: Core API in `package:uroman/uroman.dart` uses no `dart:io` and runs seamlessly in Flutter Web, Chrome, and Node/WASM.
- **Flutter Friendly**: Offsets in `Edge` provide both Python code-point indices and native Dart UTF-16 code unit indices, ready for `TextSelection`, `TextSpan`, and in-place highlighting.
- **High Fidelity**: Differential verification against upstream Python 3.13 uroman across 44,800+ characters, 24 script benchmarks, and multiple formats (`str`, `edges`, `alts`, `lattice`).
- **Full CLI**: Matches all user-facing Python uroman command-line interface flags and behaviors.

---

## Usage

### Basic Romanization

```dart
import 'package:uroman/uroman.dart';

void main() {
  final uroman = Uroman();

  // Basic string romanization
  print(uroman.romanizeString('Игорь Стравинский')); // Igor Stravinsky
  print(uroman.romanizeString('Καλημέρα'));          // Kalemera
  print(uroman.romanizeString('مرحبا'));             // mrhba
  print(uroman.romanizeString('三千二百五十四'));      // 3254
}
```

### Language-Specific Romanization

Some characters are pronounced differently depending on the language. Supply an optional ISO 639-3 language code (`lcode`) to select language-specific romanization rules:

```dart
// Default Slavic pronunciation
print(uroman.romanizeString('Игорь')); // Igor

// Ukrainian pronunciation
print(uroman.romanizeString('Игорь', lcode: 'ukr')); // Yhor
```

#### Supported Language Codes

Most writing systems (such as Latin, Hebrew, Chinese Pinyin, Japanese Kana, Korean Hangul, Amharic, etc.) work automatically without specifying a language code.

The optional `lcode` parameter activates specialized phonetic, transliteration, or schwa-deletion rules for the following languages:

| Category | ISO Code | Language | Special Rules |
| :--- | :--- | :--- | :--- |
| **Greek** | `ell` | Modern Greek | Digraph pronunciations (`ντ` &rarr; `d`/`nt`, `μπ` &rarr; `b`/`mp`, `γκ` &rarr; `g`) |
| | `grc` | Ancient / Koine Greek | Classical aspirated consonants and diphthongs |
| | `pnt` | Pontic Greek | Pontic dialect phonology |
| **Middle Eastern** | `ara` | Arabic | Solar consonant assimilations and diacritics |
| | `fas` | Persian / Farsi | Farsi vowel mappings (`e`, `o`) and consonant adjustments |
| | `pus` | Pashto | Pashto-specific letters (`ښ`, `ږ`, `ځ`, `څ`, etc.) |
| | `uig` | Uyghur | Uyghur Arabic-script vowel orthography |
| | `yid` | Yiddish | Hebrew-script Yiddish orthography and digraphs |
| **Cyrillic** | `rus` | Russian | Russian palatalization and iotated vowel rules |
| | `ukr` | Ukrainian | Ukrainian `г` &rarr; `h`/`y`, `и` &rarr; `y`, `і` &rarr; `i`, `ї` &rarr; `yi` |
| | `bel` | Belarusian | Belarusian `ў` &rarr; `w`, `г` &rarr; `h` |
| | `bul` | Bulgarian | Bulgarian `ъ` &rarr; `a`, `щ` &rarr; `sht` |
| | `mkd` / `mkd2` | Macedonian | Macedonian `ѓ`, `ќ`, `ѕ`, `џ` (standard & alt without diacritics) |
| | `srp` / `srp2` | Serbian | Serbian digraphs (`đ` &rarr; `dj`, `џ` &rarr; `dz`; standard & alt) |
| | `kaz` | Kazakh | Cyrillic Kazakh vowels and consonants (`ә`, `ғ`, `қ`, `ң`, `ө`, `ұ`, `ү`, `h`) |
| | `kir` | Kyrgyz | Cyrillic Kyrgyz vowels and consonants |
| | `oss` | Ossetic | Ossetic `æ` and ejectives |
| **European & Turkic** | `deu` | German | Umlauts (`ä` &rarr; `ae`, `ö` &rarr; `oe`, `ü` &rarr; `ue`) and `ß` &rarr; `ss` |
| | `tur` | Turkish | Dotted / dotless `i`, `ç` &rarr; `ch`, `ş` &rarr; `sh` |
| | `lav` | Latvian | Macron vowels (`ā` &rarr; `aa`, etc.) and palatal consonants (`ķ`, `ļ`, `ņ`, `ģ`) |
| | `lit` | Lithuanian | Ogonek vowels and accents |
| | `eng` | English | Grade 2 Braille contractions and Latin "oo" alternative |
| **South Asian (Schwa Rules)** | `san` | Sanskrit | Retains word-final inherent `a` in Devanagari (suppresses schwa deletion) |
| | `asm` | Assamese | Deletes word-final schwa in Bengali-Assamese script |
| | `ben` | Bengali | Deletes word-final schwa in Bengali script |
| | `guj` | Gujarati | Deletes word-final schwa in Gujarati script |
| | `kas` | Kashmiri | Deletes word-final schwa |
| | `pan` | Punjabi | Deletes word-final schwa in Gurmukhi script |

### Formats & Edge Offsets

By default, `romanizeString` returns a plain `String` (`RomFormat.str`). You can also request structured `Edge` objects with offsets for syntax highlighting, search indexing, or alignment:

```dart
final edges = uroman.romanizeString(
  'ちょっと',
  format: RomFormat.edges,
) as List<Edge>;

for (final edge in edges) {
  print('${edge.txt} at utf-16 [${edge.utf16Start}..${edge.utf16End}]');
}
// cho at utf-16 [0..2]
// tto at utf-16 [2..4]
```

Available formats:
- `RomFormat.str`: Simple romanized string.
- `RomFormat.edges`: Best path through the lattice with offsets.
- `RomFormat.alts`: Best path including alternative readings.
- `RomFormat.lattice`: Complete lattice containing all candidate edges.

---

## Command-Line Interface (CLI)

The package includes a CLI matching upstream Python `uroman`:

```bash
# Romanize direct arguments
dart run uroman "Игорь Стравинский"
dart run uroman "Ντέιβις Καπ" -l ell
dart run uroman "ちょっとまってください" -f edges

# Romanize a file
dart run uroman -i input.txt -o output.txt

# Stream from stdin to stdout
cat input.txt | dart run uroman
```

### CLI Options

| Flag                    | Description                                                  |
| ----------------------- | ------------------------------------------------------------ |
| `-i, --input_filename`  | Input file (default: stdin)                                  |
| `-o, --output_filename` | Output file (default: stdout)                                |
| `-l, --lcode`           | ISO 639-3 language code (e.g. `eng`, `ell`, `hin`)           |
| `-f, --rom_format`      | Output format: `str` (default), `edges`, `alts`, `lattice`   |
| `-c, --cache_size`      | Token cache size for speed (default: `65536`)                |
| `-d, --decode_unicode`  | Decode Unicode escape sequences (e.g. `\u03B4` to δ)         |
| `--max_lines`           | Limit romanization to the first N lines                      |
| `--silent`              | Suppress progress indicators                                 |
| `--data_dir`            | Custom resource directory (defaults to embedded data bundle) |
| `--version`             | Print version                                                |
| `-h, --help`            | Print help                                                   |

---

## Platform Separation

To guarantee web compatibility without bloat:
- **`package:uroman/uroman.dart`**: Web-safe entry point. Contains the complete engine with embedded resource tables. Use this in Flutter mobile, desktop, and web apps.
- **`package:uroman/uroman_io.dart`**: Standalone I/O extras. Adds `UromanIo.fromDataDir` and `romanizeFile` using `dart:io`. Use this for server-side tools or CLI scripts.

---

## Upstream Compatibility & Improvements

This package was developed and differentially tested against upstream Python uroman (commit `86a196e363e98df2ba0e86b4ea690676519817f2`).

While 99.9%+ of romanization outputs remain identical, this Dart implementation intentionally fixes several known upstream bugs and data typos. For technical details, see: [doc/upstream_quirks.md](doc/upstream_quirks.md).

---

## License & Attribution

This Dart port is open-sourced under the MIT License.

The underlying data tables and original romanization algorithms are from upstream [uroman](https://github.com/isi-nlp/uroman) by Ulf Hermjakob, USC Information Sciences Institute. Any publication of projects using uroman shall acknowledge its use:

> "This project uses the universal romanizer software 'uroman' written by Ulf Hermjakob, USC Information Sciences Institute (2015-2020)".
>
> *Bibliography*: Ulf Hermjakob, Jonathan May, and Kevin Knight. 2018. Out-of-the-box universal romanization tool uroman. In *Proceedings of the 56th Annual Meeting of Association for Computational Linguistics, Demo Track*.

See the [LICENSE](LICENSE) file for complete terms.
