# Bug Report & Suggested Fixes for Upstream `uroman`

During an independent validation and cross-language verification of `uroman`, we identified several minor bugs and typos in `uroman.py` and `data/romanization-table.txt`. Below is a summary of each issue, reproducible examples demonstrating the incorrect output, and recommended fixes.

---

### 1. Data Typo `:::t` Leaves Archaic Georgian Letters Unromanized

* **File:** `data/romanization-table.txt` (lines 708, 746, 759, 778)
* **Issue:** Four lines have a three-colon typo (`:::t`) instead of the standard two-colon delimiter (`::t`). When parsed, `t` loads as `None`, which overwrites the valid Unicode fallback rules and leaves the characters unromanized in the final output.
* **Reproducible Example:**
  ```python
  u.romanize_string("ჳ Ⴣ Ჳ ⴣ")
  ```
  * **Current Upstream Output:** `'ჳ Ⴣ Ჳ ⴣ'` *(unromanized native script)*
  * **Expected Output:** `'w W W w'`
* **Suggested Fix:** Change `:::t` to `::t` on lines 708, 746, 759, and 778:
  ```diff
  - ::s ჳ :::t w ::comment GEORGIAN LETTER WE
  + ::s ჳ ::t w ::comment GEORGIAN LETTER WE
  - ::s Ⴣ :::t W ::comment GEORGIAN LETTER YIE
  + ::s Ⴣ ::t W ::comment GEORGIAN LETTER YIE
  - ::s Ჳ :::t W ::comment GEORGIAN MTAVRULI CAPITAL LETTER YIE
  + ::s Ჳ ::t W ::comment GEORGIAN MTAVRULI CAPITAL LETTER YIE
  - ::s ⴣ :::t w ::comment GEORGIAN SMALL LETTER WE
  + ::s ⴣ ::t w ::comment GEORGIAN SMALL LETTER WE
  ```

---

### 2. Cross-Script Gemination Doubling Foreign Consonants

* **File:** `uroman.py` (line 1436)
* **Issue:** A variable is compared with itself:
  ```python
  if (uroman.chr_script_name(prev_char) == uroman.chr_script_name(prev_char)):
  ```
  Because this is always `True`, Japanese small tsu (`っ`) and Gurmukhi addak (`\u0A71` / `ੱ`) erroneously double consonants across different scripts (such as Latin).
* **Reproducible Examples:**
  ```python
  u.romanize_string("っb")        # Japanese small tsu + Latin b
  u.romanize_string("\u0A71k")    # Gurmukhi addak + Latin k
  ```
  * **Current Upstream Output:** `'bb'` and `'kk'` *(falsely doubled foreign consonants)*
  * **Expected Output:** `'tsub'` and `"'k"` *(clean fallbacks to table mappings `::s っ ::t tsu` and `::s ੱ ::t '`)*
* **Suggested Fix:** Verify that the following character belongs to the same script:
  ```python
  char_script = uroman.chr_script_name(first_char)
  script_matches = (prev_char in 'っッ' and char_script in ('Hiragana', 'Katakana')) or \
                   (prev_char == '\u0A71' and char_script == 'Gurmukhi')
  if script_matches:
  ```

---

### 3. Trailing Space Left at Sentence End on CJK Full Stops (`end == len + 1` Bug)

* **File:** `uroman.py` (line 1519)
* **Issue:** Space trimming checks:
  ```python
  if rom.endswith(' ') and ((end == len(full_string)+1) or (next_char == ' ')):
  ```
  Because `end` can never exceed `len(full_string)`, `end == len(full_string)+1` is unreachable. Consequently, punctuation rules with a trailing space (like CJK full stop `::s 。 ::t ". "`) leave an unwanted trailing space at the end of every sentence.
* **Reproducible Examples:**
  ```python
  u.romanize_string("加拿大。", lcode="zho")
  u.romanize_string("ちょっとまってください。", lcode="jpn")
  ```
  * **Current Upstream Output:** `'jianada. '` and `'chottomattekudasai. '` *(trailing space)*
  * **Expected Output:** `'jianada.'` and `'chottomattekudasai.'` *(clean sentence boundary)*
* **Suggested Fix:**
  ```diff
  - if rom.endswith(' ') and ((end == len(full_string)+1) or (next_char == ' ')):
  + if rom.endswith(' ') and ((end >= len(full_string)) or (next_char == ' ')):
  ```

---

### 4. Backwards Context Traversal Skips Vertices and Erroneously Deletes Thai Vowel

* **File:** `uroman.py` (lines 2314–2315 in `find_rom_edge_path_backwards`)
* **Issue:** After an edge is found ending at `old_end2`, `end2` is set to `new_edge.start`. Because `new_edge.start <= old_end2`, the condition `if old_end2 >= end2: end2 -= 1` is **always True**. This unconditionally skips the vertex at `new_edge.start`.
* **Reproducible Example:**
  ```python
  # Testing backwards context lookup across contiguous single-character edges:
  lat = Lattice('hello', uroman=u)
  for i in range(5):
      lat.add_edge(Edge(i, i + 1, 'x', 'test'))

  edges = lat.find_rom_edge_path_backwards(0, 5, min_char=4)
  print([(e.start, e.end) for e in edges])
  ```
  * **Current Upstream Output:** `[(0, 1), (2, 3), (4, 5)]` *(skipped edges `(1, 2)` and `(3, 4)`!)*
  * **Impact on Real Text:** In Thai word `ออสเตรีย` ("Austria", line 1 of `test/fixtures/text/tha.txt`), vertex 376 is skipped when looking up left context for index 377, causing the second `อ` to be deleted as `"" "rom del"` instead of recognized as the vowel `"o"`.
* **Suggested Fix:** Only decrement `end2` when no edge was found:
  ```diff
  - if old_end2 >= end2:
  -     end2 -= 1
  + if not new_edge:
  +     end2 -= 1
  ```

---

### 5. Missing Raw-String Prefix in Word-Start Vowel Regex

* **File:** `uroman.py` (line 1720 in `add_default_abugida_vowel`)
* **Issue:**
  ```python
  if self.is_at_start_of_word(start) and not regex.search('r[aeiou]', rom):
  ```
  The string `'r[aeiou]'` is missing the `r` raw-string prefix. Python interprets this as the literal letter `'r'` followed by a vowel, rather than testing whether `rom` already contains a vowel.
* **Suggested Fix:**
  ```diff
  - if self.is_at_start_of_word(start) and not regex.search('r[aeiou]', rom):
  + if self.is_at_start_of_word(start) and not regex.search(r'[aeiou]', rom):
  ```

---

### 6. Tibetan Two-Letter Syllable Cost Compares Global String Index

* **File:** `uroman.py` (line 1613 in `pick_tibetan_vowel_edge`)
* **Issue:**
  ```python
  elif n_letters == 2:
      cost = 0 if i == 0 else 0.1
  ```
  `rel_pos = i - first_letter_position` was calculated on line 1602, but line 1613 checks global string index `i == 0`. When a 2-letter syllable appears anywhere after index 0 (e.g. after a space or prefix like `" གང"`), `i == 0` is `False` for both letters, causing an unintended cost tie (`0.1` vs `0.1`).
* **Suggested Fix:**
  ```diff
  - cost = 0 if i == 0 else 0.1
  + cost = 0 if rel_pos == 0 else 0.1
  ```

---

### 7. Numeric Value `0` Dropped from Rules During Initialization (`0 == False`)

* **File:** `uroman.py` (line 174)
* **Issue:**
  ```python
  if not (value in (None, [], False)):
      self.__dict__[kw_arg2] = value
  ```
  In Python, `bool` is a subclass of `int` and `0 == False` evaluates to `True`. Therefore, `(0 in (None, [], False))` evaluates to `True`, causing any rule with `::num 0` (e.g. Klingon digit `0` or Chinese numeral `〇`) to silently lose its numeric attribute upon loading.
* **Suggested Fix:**
  ```diff
  - if not (value in (None, [], False)):
  + if value is not None and value != [] and value is not False:
  ```
