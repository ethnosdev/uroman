## 1.1.1

- Update README to list all language codes that matter.

## 1.1.0

Diverging from the upstream Python with the following improvements:

- Fixed archaic Georgian letters left unromanized due to table typos.
- Removed unwanted trailing spaces after CJK and Japanese full stops (。).
- Protected against cross-script gemination (Japanese small tsu / Gurmukhi addak doubling Latin consonants).
- Ensured contiguous backwards lattice traversal without skipping vertices.
- Added direct links to upstream_quirks.md for technical diffs.
- Adopted upstream PR #17 fix: guarded right neighbor edge with `!rightEdge.active` in number pipeline fraction and percentage parsing.
- Added comprehensive regression tests for upstream issues:
  - PR #17 / Issue #16: Chinese fraction and percentage phrases with non-numeric suffixes (e.g. `百分之多少`) and valid percentages (`百分之五十` -> `50%`).
  - Issue #19: Single and compound Chinese numeral conversion (`千` -> `1000`, `一千` -> `1000`, `三万一` -> `31000`).
  - Issue #28: Explicit test for numeric value 0 preservation (`〇` and `零` -> `0`).
  - Issue #25 & #26: Cham script romanization and Latin typographic punctuation preservation (`[384] Côte d’Ivoire`).

## 1.0.0

- Initial release of `uroman` in pure Dart matching Python uroman v1.3.1.1.
- Full script support: Cyrillic, Greek, Arabic, Hebrew, Devanagari, Bengali, Tamil, Thai, Tibetan, Hangul, CJK, Braille, Egyptian hieroglyphs, and more.
- Four output formats: `str`, `edges`, `alts`, and `lattice`.
- Dual offset indexing on `Edge`: Python code-point offsets and native Dart UTF-16 code unit offsets for Flutter integration.
- Full web compatibility: `package:uroman/uroman.dart` has zero `dart:io` imports and runs on web and WASM.
- Command-line tool `bin/uroman.dart` with matching flags (`-i`, `-o`, `-l`, `-f`, `-c`, `-d`, `--max_lines`, `--silent`).
- Comprehensive test coverage and differential verification against Python uroman across 44,800+ Unicode characters and 24 script benchmarks.
