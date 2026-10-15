# Upstream Divergences and Bug Fixes

This document tracks all intentional divergences, bug fixes, data corrections, and architectural enhancements in this repository compared to upstream Python [uroman](https://github.com/isi-nlp/uroman) (commit `86a196e363e98df2ba0e86b4ea690676519817f2`, v1.3.1.1).

It serves as a living log:
1. To periodically verify whether upstream has adopted these fixes or introduced new changes.
2. To document newly added features and improvements in this Dart implementation.

---

## 1. Bug Fixes & Algorithmic Corrections

### 1.1 Cross-Script Gemination Protection (Japanese small tsu & Gurmukhi addak)
* **Upstream Reference:** `uroman.py` line 1436
* **Issue:** Upstream checked `chr_script_name(prev_char) == chr_script_name(prev_char)` (comparing a variable with itself). Because this always evaluated to `True`, gemination markers doubled foreign consonants across different scripts.
* **Dart Fix:** Verifies that the subsequent consonant belongs to the same script family (`Hiragana`/`Katakana` for tsu, `Gurmukhi` for addak). Cross-script consonants cleanly fall back to table mappings.
* **Examples:**
  * **Input:** `'っb'` (Japanese small tsu + Latin b)
    * *Upstream:* `'bb'` *(erroneously doubled Latin consonant)*
    * *This repo:* `'tsub'` *(fallback to table rule `::s っ ::t tsu`)*
  * **Input:** `'\u0A71k'` (Gurmukhi addak + Latin k)
    * *Upstream:* `'kk'` *(erroneously doubled Latin consonant)*
    * *This repo:* `"'k"` *(fallback to table rule `::s ੱ ::t '`)*

---

### 1.2 Trailing Space Trimming at Sentence Boundary (`end == len + 1` Bug)
* **Upstream Reference:** `uroman.py` line 1519
* **Issue:** Upstream checked `if rom.endswith(' ') and ((end == len(full_string)+1) or (next_char == ' ')):`. Because `end` is bounded by `len(full_string)`, `end == len(full_string)+1` was unreachable. Punctuation rules with trailing spaces (like CJK full stop `::s 。 ::t ". "`) left an unwanted trailing space at the end of lines and sentences.
* **Dart Fix:** Checks `(lat.isAtStringEnd && end >= lat.maxVertex) || nextChar == ' '`, trimming the trailing space only at the string/sentence boundary while preserving mid-line sentence separation.
* **Examples:**
  * **Input:** `'加拿大。'` (`lcode: 'zho'`)
    * *Upstream:* `'jianada. '` *(trailing space)*
    * *This repo:* `'jianada.'` *(clean sentence boundary)*
  * **Input:** `'ちょっとまってください。'` (`lcode: 'jpn'`)
    * *Upstream:* `'chottomattekudasai. '` *(trailing space)*
    * *This repo:* `'chottomattekudasai.'` *(clean sentence boundary)*

---

### 1.3 Crash on Fractions / Percentages with Non-Numeric Suffixes (PR #17 / Issue #16)
* **Upstream Reference:** `uroman.py` lines 423–428; upstream Issue #16 / PR #17
* **Issue:** In number pipeline fraction/percentage combination (G5), `best_right_neighbor_edge` following a fraction connector (like `百分之`) could return a non-numeric `Edge` (or an inactive `NumEdge`) when followed by non-digits. Accessing `right_edge.value` raised an unhandled `AttributeError: 'Edge' object has no attribute 'value'`, crashing uroman.
* **Dart Fix:** Added a guard `if (rightEdge is! NumEdge || !rightEdge.active || rightEdge.value == null) continue;`. When followed by non-numbers, it cleanly falls back to normal romanization.
* **Examples:**
  * **Input:** `'百分之多少'` (`lcode: 'zho'`)
    * *Upstream:* Crashes with `AttributeError: 'Edge' object has no attribute 'value'`
    * *This repo:* `'baifenzhiduoshao'` *(clean fallback)*
  * **Input:** `'百分之五十'` (`lcode: 'zho'`)
    * *Upstream & This repo:* `'50%'` *(valid percentages continue to convert correctly)*

---

### 1.4 Backwards Lattice Traversal Contiguity (Thai Vowel Deletion Bug)
* **Upstream Reference:** `uroman.py` lines 2314–2315 in `find_rom_edge_path_backwards`
* **Issue:** Upstream contained `if old_end2 >= end2: end2 -= 1`. Because `end2` is set to `new_edge.start <= old_end2`, this condition unconditionally decremented `end2` after finding an edge, skipping adjacent left vertices and creating gaps in traversal.
* **Dart Fix:** Only decrements `currentEnd` when no edge is found. Backwards traversal remains contiguous.
* **Examples:**
  * **Contiguous Edge Traversal:** On consecutive single-character edges `[(0, 1), (1, 2), (2, 3), (3, 4), (4, 5)]`:
    * *Upstream:* Returns `[(0, 1), (2, 3), (4, 5)]` *(skipped vertices `1` and `3`)*
    * *This repo:* Returns `[(1, 2), (2, 3), (3, 4), (4, 5)]` *(strictly contiguous)*
  * **Real-World Impact (Thai `ออสเตรีย` / "Austria"):** In upstream, skipping a vertex during left-context lookup caused the second `อ` to be deleted as `"" "rom del"`. In this repo, it is properly recognized as the vowel `"o"` (`"song"`).

---

### 1.5 Missing Raw-String Prefix in Word-Start Vowel Regex
* **Upstream Reference:** `uroman.py` line 1720 in `add_default_abugida_vowel`
* **Issue:** Upstream checked `not regex.search('r[aeiou]', rom)` without an `r` prefix. Python treated this as literal letter `'r'` followed by a vowel, rather than checking if `rom` already contains a vowel.
* **Dart Fix:** Uses `RegExp(r'[aeiou]')` so candidates that already contain vowels at word start are recognized properly without duplicate vowel additions.

---

### 1.6 Tibetan Syllable Consonant Cost Consistency
* **Upstream Reference:** `uroman.py` line 1613 in `pick_tibetan_vowel_edge`
* **Issue:** In 2-letter syllables, upstream checked global string index `i == 0` instead of relative syllable position `rel_pos == 0`. When a 2-letter syllable appeared after whitespace or a prefix, `i == 0` was `False`, causing an unintended cost tie (`0.1` vs `0.1`).
* **Dart Fix:** Checks `relPos == 0`, ensuring deterministic root-consonant vowel selection regardless of string offset.
* **Examples:**
  * **Input:** `'གང'` vs `' གང'` (`lcode: 'bod'`)
    * *Upstream:* Cost calculation varied depending on preceding whitespace.
    * *This repo:* Consistently produces `'gang'` and `' gang'`.

---

### 1.7 Numeric Value `0` Dropped from Rules (`0 == False`)
* **Upstream Reference:** `uroman.py` line 174; upstream Issue #28
* **Issue:** In Python, `bool` is a subclass of `int` (`0 == False` is `True`). The rule attribute parser checked `if not (value in (None, [], False)):`, which dropped `::num 0` on digits with value 0.
* **Dart Fix:** Strongly typed models preserve `numValue: 0`.
* **Examples:**
  * **Input:** `'〇'` or `'零'` (Chinese zero)
    * *Upstream:* Dropped `::num 0` attribute during rule loading.
    * *This repo:* Preserves numeric value `0`, romanizing to `'0'` and converting in compound numbers like `'三万零一'` -> `'30001'`.

---

### 1.8 Defaultdict Auto-Vivification of Dummy Keys
* **Upstream Reference:** `uroman.py` line 861
* **Issue:** Querying `if name := self.dict_str[('name', char)]:` on Python's `defaultdict(str)` silently inserted dummy entries with empty string values (e.g. `('name', '፡ '): ''`) into the global dictionary during second romanization filtering.
* **Dart Fix:** Clean Dart map lookups do not auto-vivify dummy keys on query misses.

---

## 2. Data & Table Fixes

### 2.1 Typo `:::t` for Archaic Georgian Letters
* **Upstream Reference:** `data/romanization-table.txt` lines 708, 746, 759, 778
* **Issue:** Four lines contained a three-colon typo `:::t` instead of `::t`. The slot parser loaded `t` as `None`, creating manual rules that overwrote Unicode fallback rules and left the characters unromanized.
* **Dart Fix:** Corrected `:::t` to `::t` in `data/romanization-table.txt`.
* **Examples:**
  * **Input:** `'ჳ Ⴣ Ჳ ⴣ'` (Georgian letters WE and YIE, uppercase, lowercase, and Mtavruli)
    * *Upstream:* `'ჳ Ⴣ Ჳ ⴣ'` *(untranslated raw characters)*
    * *This repo:* `'w W W w'`

---

## 3. Architectural & Feature Enhancements in Dart

### 3.1 Dual Offset Indexing (Code Points & UTF-16 Code Units)
* **Upstream:** `Edge` only records Unicode code-point offsets (`start`, `end`).
* **This repo:** `Edge` provides both code-point offsets (`start`, `end`) and native UTF-16 code unit offsets (`utf16Start`, `utf16End`). This enables direct integration with Dart string slicing, Flutter `TextSpan`, `TextSelection`, and in-place search highlighting without manual UTF-16 re-indexing.

### 3.2 Zero-I/O Embedded Data Bundle
* **Upstream:** Requires reading 9 resource files from the filesystem at startup.
* **This repo:** Pre-compiles all 9 resource tables into [`lib/src/data/embedded_data.g.dart`](../lib/src/data/embedded_data.g.dart). `Uroman()` initializes with zero filesystem I/O, enabling out-of-the-box support for Flutter Web, WebAssembly (WASM), Chrome, iOS, Android, and servers. Filesystem loading remains available on standalone platforms via `UromanIo.fromDataDir(...)`.

### 3.3 Standard RFC-8259 JSON Output
* **Upstream:** Emits a custom non-standard bracket format (`[[0, 1, "txt", "type"][...]]`).
* **This repo:** Adds [`Edge.toJson()`](../lib/src/models/edge.dart) producing standard RFC-8259 JSON maps (`{"start": 0, "end": 1, "txt": "...", "type": "..."}`) for modern REST APIs and Dart/Flutter JSON tooling, while preserving [`Edge.toPythonJson()`](../lib/src/models/edge.dart) and `Uroman.formatResult(...)` for exact upstream CLI compatibility.
