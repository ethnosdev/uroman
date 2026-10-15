## 1.1.0

Expanded the section to clearly list the improvements made over upstream Python:

- Fixed archaic Georgian letters left unromanized due to table typos.
- Removed unwanted trailing spaces after CJK and Japanese full stops (。).
- Protected against cross-script gemination (Japanese small tsu / Gurmukhi addak doubling Latin consonants).
- Ensured contiguous backwards lattice traversal without skipping vertices.
- Added direct links to upstream_quirks.md and upstream_bug_report.md for full technical diffs and test cases.

## 1.0.0

- Initial release of `uroman` in pure Dart matching Python uroman v1.3.1.1.
- Full script support: Cyrillic, Greek, Arabic, Hebrew, Devanagari, Bengali, Tamil, Thai, Tibetan, Hangul, CJK, Braille, Egyptian hieroglyphs, and more.
- Four output formats: `str`, `edges`, `alts`, and `lattice`.
- Dual offset indexing on `Edge`: Python code-point offsets and native Dart UTF-16 code unit offsets for Flutter integration.
- Full web compatibility: `package:uroman/uroman.dart` has zero `dart:io` imports and runs on web and WASM.
- Command-line tool `bin/uroman.dart` with matching flags (`-i`, `-o`, `-l`, `-f`, `-c`, `-d`, `--max_lines`, `--silent`).
- Comprehensive test coverage and differential verification against Python uroman across 44,800+ Unicode characters and 24 script benchmarks.
